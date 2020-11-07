#!/usr/bin/python3

from cli.git import GitCli
from cli.gitlab import GitlabCli

import os
import argparse
import sys
import logging
import tempfile
import shutil

parser = argparse.ArgumentParser()

parser.add_argument('--clone', action='store', type=str, required=True,
                    help='Git source repository')
parser.add_argument('--ref', action='store', type=str,
                    help='Git reference to use')
parser.add_argument('--pull-request', action='store', type=int,
                    help='Git pullrequest reference to use')
parser.add_argument('--push', action='store', type=str, required=True,
                    help='Gitlab instance url')
parser.add_argument('--repo', action='store', type=str, required=True,
                    help='owner/project in Gitlab instance')
parser.add_argument('--trigger-build', action='store_true', default=False,
                    help='Trigger build in Gitlab CI/CD')
parser.add_argument('--target-branch', action='store', type=str,
                    help='Target branch of the pullrequest.')
parser.add_argument('--noclean', action='store_true', default=False,
                    help='Do not delete build VM')
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

    if not os.environ.get('GITLAB_API_TOKEN', None):
        logger.error("Cannot find GITLAB_API_TOKEN")
        return 1

    tmpdir = tempfile.mkdtemp()
    try:
        git = GitCli(tmpdir)
        logger.debug('Clone %s' % args.clone)
        git.clone(args.clone, args.target_branch)
        if args.pull_request:
            remote_ref = '+refs/pull/*/head:refs/remotes/origin/pr/*'
            logger.debug('Fetch {} {}'.format('origin', remote_ref))
            git.fetch('origin', remote_ref)
            if args.target_branch:
                branch = 'pr-{}-{}'.format(args.pull_request, args.target_branch)
            else:
                branch = 'pr-%s' % args.pull_request
            ref = 'origin/pr/%s' % args.pull_request
            logger.debug('Checkout %s' % ref)
            git.checkout(ref, branch=branch)

        else:
            logger.debug('Fetch {} {}'.format('origin', args.ref))
            git.fetch('origin', args.ref)
            branch = args.ref
            if args.ref != 'master':
                logger.debug('Checkout %s' % args.ref)
                git.checkout(args.ref, branch=branch)

        parsed_repo = args.repo.rstrip('/').split('/')
        repo_owner = parsed_repo[0]
        repo_name = parsed_repo[1]

        url = 'https://{repo_owner}:{token}@{gitlab_url}/{repo}'.format(
            token=os.environ['GITLAB_API_TOKEN'],
            gitlab_url=args.push.replace('https://', ''), repo=args.repo,
            repo_owner=repo_owner)
        logger.debug('Add remote %s' % repo_owner)
        git.remote_add(repo_owner, url)
        logger.debug('Push to %s', repo_owner)
        git.push(repo_owner, branch, force=True)

        if args.trigger_build:
            cli = GitlabCli(url=args.push, token=os.environ['GITLAB_API_TOKEN'])
            pipeline_options = {
                'ref': branch,
                'variables': [
                    {
                        'key': 'NO_CLEANUP',
                        'value': str(int(args.noclean))
                    }
                ]
            }
            logger.debug('Trigger build for %s' % repo_name)
            cli.create_pipeline(repo_name, pipeline_options)
    finally:
        shutil.rmtree(tmpdir)


if __name__ == '__main__':
    sys.exit(main())
