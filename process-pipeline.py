#!/usr/bin/python3
# -*- encoding: utf8 -*-
#
# The Qubes OS Project, http://www.qubes-os.org
#
# Copyright (C) 2020 Frédéric Pierret <frederic.pierret@qubes-os.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

from cli.cli_github import GithubCli, GithubAppCli
from cli.cli_gitlab import GitlabCli, GitlabCliError

import os
import argparse
import sys
import logging
import time
import traceback

parser = argparse.ArgumentParser()

parser.add_argument(
    "--github-component",
    action="store",
    type=str,
    required=True,
    help="Github project name (e.g. qubes-linux-kernel)",
)
parser.add_argument(
    "--github-owner",
    action="store",
    type=str,
    required=True,
    help="Github owner of the project where the pullrequest " "is made.",
)

parser.add_argument(
    "--gitlab-component",
    action="store",
    type=str,
    required=True,
    help="Gitlab project name (e.g. qubes-linux-kernel)",
)
parser.add_argument(
    "--gitlab-owner",
    action="store",
    type=str,
    required=True,
    help="Gitlab owner of the project where the pipeline is ran",
)

# reference to process: branch or pullrequest
parser.add_argument(
    "--sha", action="store", type=str, required=False, help="Git commit SHA to use"
)
parser.add_argument(
    "--branch", action="store", type=str, required=False, help="Git reference to use"
)
parser.add_argument(
    "--pull-request",
    action="store",
    type=int,
    required=False,
    help="Pullrequest number into the project",
)

# GitlabPipelineStatus knows pipeline id status to send to Github PR
parser.add_argument(
    "--pipeline-id", action="store", type=int, required=False, help="Gitlab pipeline ID"
)
parser.add_argument(
    "--pipeline-status",
    action="store",
    type=str,
    required=False,
    help="Gitlab pipeline status",
)

parser.add_argument("--verbose", action="store_true")
parser.add_argument("--debug", action="store_true")

logger = logging.getLogger("process-pipeline")
console_handler = logging.StreamHandler(sys.stderr)
logger.addHandler(console_handler)


def gitlab_to_github_status(status):
    if status in (
        "created",
        "waiting_for_resource",
        "preparing",
        "pending",
        "running",
        "manual",
        "scheduled",
    ):
        return "pending"

    if status in ("canceled", "skipped"):
        return "error"

    if status == "failed":
        return "failure"

    if status == "success":
        return status


def get_url(gitlab_url, pipeline_id):
    return gitlab_url + "/-/pipelines/%s" % pipeline_id


class InternalError(Exception):
    pass


def main(args=None):
    args = parser.parse_args(args)

    if args.debug:
        logger.setLevel(logging.DEBUG)
    elif args.verbose:
        logger.setLevel(logging.INFO)
    else:
        logger.setLevel(logging.ERROR)

    if args.pull_request is None and args.branch is None and args.sha is None:
        parser.error("Please provide one of --branch, --pull-request or --sha")

    gitlab_url = "https://gitlab.com"
    github_app_id = os.getenv("GITHUB_APP_ID")
    pem_file_path = os.getenv("PEM_FILE_PATH")
    github_installation_id = os.getenv("GITHUB_INSTALLATION_ID")
    gitlab_token = os.getenv("GITLAB_API_TOKEN")
    github_token = os.getenv("GITHUB_API_TOKEN")
    github_project = f"{args.github_owner}/{args.github_component}"
    exit_code = 1

    try:

        if not github_app_id:
            raise InternalError("Cannot find GITHUB_APP_ID!")

        if not pem_file_path:
            raise InternalError("Cannot find PEM_FILE_PATH!")

        if not github_installation_id:
            raise InternalError("Cannot find GITHUB_INSTALLATION_ID!")

        if not gitlab_token:
            raise InternalError("Cannot find GITLAB_API_TOKEN!")

        if not github_token:
            raise InternalError("Cannot find GITHUB_API_TOKEN!")

        try:
            with open(pem_file_path) as fd:
                github_private_key = fd.read().encode("utf8")
        except Exception as e:
            raise InternalError("Cannot read GITHUB_PEM_FILE_PATH") from e

        gitlab_cli = GitlabCli(url=gitlab_url, token=gitlab_token)
        github_cli = GithubCli(token=github_token)
        github_appcli = GithubAppCli(
            github_app_id, github_private_key, github_installation_id
        )

        pipeline_id = args.pipeline_id
        pipeline_status = args.pipeline_status
        pipeline = None

        if args.pull_request:
            github_pr = github_cli.get_pull_request(
                args.github_owner, args.github_component, args.pull_request
            )

            if not github_pr:
                raise InternalError(
                    "Cannot find Github PR for {} with reference 'pr-{}'".format(
                        args.github_component, args.github_pull_request
                    )
                )

            github_ref = github_pr.head.sha
        elif args.branch:
            github_branch = github_cli.get_branch(
                args.github_owner, args.github_component, args.branch
            )
            if not github_branch:
                raise InternalError(
                    "Cannot find Github branch for {} with reference '{}'".format(
                        args.github_component, args.github_branch
                    )
                )
            github_ref = github_branch.commit.sha
        elif args.sha:
            # sha reference /merge github reference. We need to get the parent
            project = gitlab_cli.get_project(args.gitlab_owner, args.gitlab_component)
            pipeline_commit = project.commits.get(args.sha)
            if not pipeline_commit:
                raise InternalError(
                    "Cannot find commit with reference '{}': ".format(args.sha)
                )
            parsed_message = pipeline_commit.message.split()

            if (
                len(parsed_message) >= 3
                and parsed_message[0] == "Merge"
                and parsed_message[2] == "into"
            ):
                logger.info("Use parent SHA of merge reference.")
                github_ref = parsed_message[1]
            else:
                github_ref = args.sha

        else:
            raise InternalError("Cannot find reference to use")

        if pipeline_id and not pipeline_status:
            raise InternalError("Pipeline ID provided without status")

        if not pipeline_id and pipeline_status:
            raise InternalError("Pipeline status provided without ID")

        if not pipeline_id and not pipeline_status:
            if not args.pull_request:
                raise InternalError("Pullrequest not provided")
            pipeline_ref = "pr-%s" % args.pull_request

            for _ in range(60):
                try:
                    pipeline = gitlab_cli.get_pipeline(
                        args.gitlab_owner, args.gitlab_component, pipeline_ref
                    )
                except GitlabCliError as e:
                    raise InternalError("Failed to get pipeline") from e
                if pipeline:
                    break
                time.sleep(3)

            if not pipeline:
                raise InternalError(
                    "Cannot find pipeline for {} with reference 'pr-{}'".format(
                        args.gitlab_component, args.pull_request
                    )
                )
            pipeline_id = pipeline.id
            pipeline_status = pipeline.status

        gitlab_component_url = gitlab_url + "/%s/%s" % (
            args.gitlab_owner,
            args.gitlab_component,
        )
        pipeline_url = "{}".format(get_url(gitlab_component_url, pipeline_id))

        # Send status to Github
        try:
            status = gitlab_to_github_status(pipeline_status)
            msg = f"Submitting PR status (ref={github_ref},pipeline={pipeline_id},status={status},pipeline_status={pipeline_status})"
            logger.debug(msg)
            result = github_appcli.submit_commit_status(
                github_project,
                github_ref,
                status,
                pipeline_status,
                pipeline_url,
            )
            if result.status_code > 400:
                raise InternalError(str(result.text))
        except Exception as e:
            raise InternalError(
                f"Failed to submit pullrequest status ({str(e)})"
            ) from e
        exit_code = 0
    except InternalError as e:
        logger.error(f"InternalError: {str(e)}")
        exit_code = 1
    except Exception as e:
        logger.error(f"GeneralError: {str(e)}")
        print(traceback.print_exception(*sys.exc_info()))
        exit_code = 2
    finally:
        return exit_code


if __name__ == "__main__":
    sys.exit(main())
