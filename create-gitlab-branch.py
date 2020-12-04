#!/usr/bin/python3

from cli.git import GitCli, GitException
from cli.gitlab import GitlabCli

import os
import argparse
import sys
import logging
import tempfile
import shutil

parser = argparse.ArgumentParser()

parser.add_argument('--gitlab-url', action='store', type=str, required=True,
                    help='Gitlab instance url')
parser.add_argument('--ref', action='store', type=str,
                    help='Git reference to use')
parser.add_argument('--pull-request', action='store', type=int,
                    help='Git pullrequest reference to use')
parser.add_argument('--github-component', action='store', type=str,
                    required=True,
                    help='Github project name (e.g. qubes-linux-kernel)')
parser.add_argument('--github-owner', action='store', type=str, required=True,
                    help='Github owner of the project where the pullrequest '
                         'is made.')
parser.add_argument('--gitlab-component', action='store', type=str,
                    required=True,
                    help='Gitlab project name (e.g. qubes-linux-kernel)')
parser.add_argument('--gitlab-owner', action='store', type=str, required=True,
                    help='Gitlab owner of the project where the pipeline is ran')
parser.add_argument('--verbose', action='store_true')
parser.add_argument('--debug', action='store_true')

logger = logging.getLogger('create-gitlab-branch')
console_handler = logging.StreamHandler(sys.stderr)
logger.addHandler(console_handler)


def main(args=None):
    args = parser.parse_args(args)

    if args.debug:
        logger.setLevel(logging.DEBUG)
    elif args.verbose:
        logger.setLevel(logging.INFO)
    else:
        logger.setLevel(logging.ERROR)

    if args.pull_request is None and args.ref is None:
        parser.error('Either --ref or --pull-request is required')
    if args.pull_request is not None and args.ref is not None:
        parser.error('Only one of --ref or --pull-request can be used')

    if not os.environ.get('GITHUB_API_TOKEN', None):
        logger.error("Cannot find GITHUB_API_TOKEN")
        return 1

    if not os.environ.get('GITLAB_API_TOKEN', None):
        logger.error("Cannot find GITLAB_API_TOKEN")
        return 1

    tmpdir = tempfile.mkdtemp()
    try:
        git = GitCli(tmpdir)
        github_url = 'https://github.com/{repo_owner}/{repo_name}'.format(
            repo_owner=args.github_owner,
            repo_name=args.github_component)
        logger.debug('Clone %s' % github_url)
        git.clone(github_url)

        repo_owner = args.gitlab_owner
        repo_name = args.gitlab_component

        branch = args.ref
        if args.pull_request:
            branch = 'pr-%s' % args.pull_request

        url = 'https://{repo_owner}:{token}@{gitlab_url}/{repo_owner}/{repo_name}'.format(
            token=os.environ['GITLAB_API_TOKEN'],
            gitlab_url=args.gitlab_url.replace('https://', ''),
            repo_name=repo_name,
            repo_owner=repo_owner)

        logger.debug('Add remote %s' % repo_owner)
        git.remote_add(repo_owner, url)

        logger.debug('Delete remote branch %s' % branch)
        try:
            git.delete_remote_branch(repo_owner, branch)
        except GitException:
            pass

        if args.pull_request:
            remote_ref = '+refs/pull/%d/merge' % args.pull_request
            ref = 'FETCH_HEAD'

            logger.debug('Fetch {} {}'.format('origin', remote_ref))
            git.fetch('origin', remote_ref)
            logger.debug('Checkout %s' % ref)
            git.checkout(ref, branch=branch)
            git.reset(ref, hard=True)
        else:
            logger.debug('Fetch {} {}'.format('origin', args.ref))
            git.fetch('origin', args.ref)
            if args.ref != 'master':
                logger.debug('Checkout %s' % args.ref)
                git.checkout(args.ref, branch=branch)

        # Before pushing new branch we cancel previous running pipelines
        # with same pr branch name
        gitlabcli = GitlabCli(url='https://gitlab.com',
                              token=os.environ['GITLAB_API_TOKEN'])
        gitlabcli.cancel_pipelines(repo_owner, repo_name, branch)

        logger.debug('Push to %s', repo_owner)
        git.push(repo_owner, branch, force=True)
    finally:
        shutil.rmtree(tmpdir)


if __name__ == '__main__':
    sys.exit(main())
