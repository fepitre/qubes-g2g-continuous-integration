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
                    help='Owner of the project where the pullrequest is made (e.g. QubesOS)')
parser.add_argument('--pull-request', action='store', type=int, required=True,
                    help='Pullrequest number into the project')
parser.add_argument('--branch', action='store', type=str, required=True,
                    help='Branch to process')
parser.add_argument('--verbose', action='store_true')
parser.add_argument('--debug', action='store_true')

logger = logging.getLogger('process-pipeline-status')
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

    github_project = None
    github_pr = None
    pipeline = None
    final_status = None

    if args.pull_request:
        github_project = '{}/{}'.format(args.owner, args.component)
        github_pr = githubcli.get_pull_request(args.owner, args.component,
                                               args.pull_request)

    pipeline_ref = '%s' % args.branch
    logger.debug("Waiting pipeline {} for {} to be created...".format(
        pipeline_ref, args.component))
    for _ in range(60):
        pipeline = gitlabcli.get_pipeline(args.component, pipeline_ref)
        if pipeline:
            break
        time.sleep(10)

    if not pipeline:
        logger.error(
            "Cannot find pipeline for {} with reference 'pr-{}'".format(
                args.component, args.pull_request))
        return 1
    gitlab_component_url = gitlab_url + '/QubesOS/%s' % args.component
    pipeline_url = "{}".format(get_url(gitlab_component_url, pipeline.id))

    try:
        if args.pull_request:
            logger.debug("Submitting initial pipeline status to Github...")
            githubappcli.submit_commit_status(
                github_project,
                github_pr.head.sha,
                gitlab_to_github_status(pipeline.status),
                pipeline.status,
                pipeline_url
            )

        # In case of retry and pipeline is already done and succeeded
        if pipeline.status != "success":
            # Timeout of 1d
            for _ in range(1440):
                pipeline.refresh()
                if pipeline.status in ('pending', 'running'):
                    githubappcli.submit_commit_status(
                        github_project,
                        github_pr.head.sha,
                        gitlab_to_github_status(pipeline.status),
                        pipeline.status,
                        pipeline_url
                    )
                    time.sleep(60)
                else:
                    final_status = pipeline.status
                    break

            if not final_status:
                logger.error("Pipeline {}: Timeout reached!".format(pipeline.id))
                final_status = 'failure'

            logger.debug("Submitting final pipeline status to Github...")
            githubappcli.submit_commit_status(
                github_project,
                github_pr.head.sha,
                gitlab_to_github_status(pipeline.status),
                pipeline.status,
                pipeline_url
            )
        else:
            final_status = pipeline.status
        logger.error("Pipeline {}: {}.".format(pipeline.id, final_status))
    except Exception as e:
        logger.error(
            "Pipeline {}: An error occurred: {}".format(pipeline.id, str(e)))


if __name__ == '__main__':
    sys.exit(main())
