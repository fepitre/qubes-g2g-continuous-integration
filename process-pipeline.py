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

from cli.github import GithubCli, GithubAppCli
from cli.gitlab import GitlabCli

import os
import argparse
import sys
import logging
import time

parser = argparse.ArgumentParser()

parser.add_argument('--component', action='store', type=str, required=True,
                    help='Project name (e.g. qubes-linux-kernel)')
parser.add_argument('--owner', action='store', type=str, required=True,
                    help='Owner of the project where the pullrequest is made '
                         '(e.g. QubesOS)')

# reference to process: branch or pullrequest
parser.add_argument('--sha', action='store', type=str, required=False,
                    help='Git commit SHA to use')
parser.add_argument('--branch', action='store', type=str, required=False,
                    help='Git reference to use')
parser.add_argument('--pull-request', action='store', type=int, required=False,
                    help='Pullrequest number into the project')

# GitlabPipelineStatus knows pipeline id status to send to Github PR
parser.add_argument('--pipeline-id', action='store', type=int, required=False,
                    help='Gitlab pipeline ID')
parser.add_argument('--pipeline-status', action='store', type=str,
                    required=False, help='Gitlab pipeline status')

parser.add_argument('--verbose', action='store_true')
parser.add_argument('--debug', action='store_true')

logger = logging.getLogger('process-pipeline')
console_handler = logging.StreamHandler(sys.stderr)
logger.addHandler(console_handler)


def gitlab_to_github_status(status):
    if status in ('created', 'waiting_for_resource', 'preparing', 'pending',
                  'running', 'manual', 'scheduled'):
        return 'pending'

    if status in ('canceled', 'skipped'):
        return 'error'

    if status == 'failed':
        return 'failure'

    if status == 'success':
        return status


def get_url(gitlab_url, pipeline_id):
    return gitlab_url + '/-/pipelines/%s' % pipeline_id


def main(args=None):
    args = parser.parse_args(args)

    if args.debug:
        logger.setLevel(logging.DEBUG)
    elif args.verbose:
        logger.setLevel(logging.INFO)
    else:
        logger.setLevel(logging.ERROR)

    if args.pull_request is None and args.branch is None and args.sha is None:
        parser.error('Please provide one of --branch, --pull-request or --sha')

    gitlab_url = 'https://gitlab.com'

    github_app_id = os.getenv("GITHUB_APP_ID")
    pem_file_path = os.getenv("PEM_FILE_PATH")
    github_installation_id = os.getenv("GITHUB_INSTALLATION_ID")
    gitlab_token = os.getenv('GITLAB_API_TOKEN')
    github_token = os.getenv('GITHUB_API_TOKEN')

    if not github_app_id:
        logger.error("Cannot find GITHUB_APP_ID!")
        return 1

    if not pem_file_path:
        logger.error("Cannot find PEM_FILE_PATH!")
        return 1

    if not github_installation_id:
        logger.error("Cannot find GITHUB_INSTALLATION_ID!")
        return 1

    if not gitlab_token:
        logger.error("Cannot find GITLAB_API_TOKEN!")
        return 1

    if not github_token:
        logger.error("Cannot find GITHUB_API_TOKEN!")
        return 1

    try:
        with open(pem_file_path) as fd:
            github_private_key = fd.read().encode('utf8')
    except:
        logger.error("Cannot read GITHUB_PEM_FILE_PATH")
        return 1

    gitlabcli = GitlabCli(url=gitlab_url, token=gitlab_token)
    githubcli = GithubCli(token=github_token)
    githubappcli = GithubAppCli(github_app_id, github_private_key,
                                github_installation_id)

    pipeline_id = args.pipeline_id
    pipeline_status = args.pipeline_status
    pipeline = None

    github_project = '{}/{}'.format(args.owner, args.component)
    if args.pull_request:
        github_pr = githubcli.get_pull_request(args.owner, args.component,
                                               args.pull_request)

        if not github_pr:
            logger.error(
                "Cannot find Github PR for {} with reference 'pr-{}'".format(
                    args.component, args.pull_request))
            return 1

        github_ref = github_pr.head.sha
    elif args.branch:
        github_branch = githubcli.get_branch(args.owner, args.component,
                                             args.branch)
        if not github_branch:
            logger.error(
                "Cannot find Github branch for {} with reference '{}'".format(
                    args.component, args.branch))
            return 1
        github_ref = github_branch.commit.sha
    elif args.sha:
        # sha reference /merge github reference. We need to get the parent
        project = gitlabcli.get_project(args.owner, args.component)
        pipeline_commit = project.commits.get(args.sha)
        if not pipeline_commit:
            logger.error("Cannot find commit with reference '{}': ".format(
                args.sha))
            return 1
        parsed_message = pipeline_commit.message.split()

        if len(parsed_message) >= 3 and parsed_message[0] == "Merge" and \
                parsed_message[2] == "into":
            logger.info("Use parent SHA of merge reference.")
            github_ref = parsed_message[1]
        else:
            github_ref = args.sha

    else:
        logger.error("Cannot find reference to use")
        return 1

    if pipeline_id and not pipeline_status:
        logger.error("Pipeline ID provided without status")
        return 1

    if not pipeline_id and pipeline_status:
        logger.error("Pipeline status provided without ID")
        return 1

    if not pipeline_id and not pipeline_status:
        if not args.pull_request:
            logger.error("Pullrequest not provided")
            return 1
        pipeline_ref = 'pr-%s' % args.pull_request
        if not gitlabcli.get_branch(args.owner, args.component, pipeline_ref):
            logger.error(
                "Submitting pipeline status to Github: missing Gitlab branch.")
            githubappcli.submit_commit_status(
                github_project,
                github_ref,
                'failure',
                'failed',
                '',
                "An error occurred while creating pull request branch."
            )
            return 1

        for _ in range(60):
            pipeline = gitlabcli.get_pipeline(
                args.owner, args.component, pipeline_ref)
            if pipeline:
                break
            time.sleep(10)

        if not pipeline:
            logger.error(
                "Cannot find pipeline for {} with reference 'pr-{}'".format(
                    args.component, args.pull_request))
            return 1
        pipeline_id = pipeline.id
        pipeline_status = pipeline.status

    gitlab_component_url = gitlab_url + '/%s/%s' % (args.owner, args.component)
    pipeline_url = "{}".format(get_url(gitlab_component_url, pipeline_id))
    # Send status to Github
    try:
        logger.debug("Submitting pipeline status to Github...")
        githubappcli.submit_commit_status(
            github_project,
            github_ref,
            gitlab_to_github_status(pipeline_status),
            pipeline_status,
            pipeline_url
        )
        logger.debug("Pipeline {}: {}.".format(pipeline_id, pipeline_status))
    except Exception as e:
        logger.error(
            "Pipeline {}: An error occurred: {}".format(pipeline_id, str(e)))


if __name__ == '__main__':
    sys.exit(main())
