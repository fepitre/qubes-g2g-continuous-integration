#!/usr/bin/python3

from cli.git import GitCli, GitException
from cli.github import GithubAppCli
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
parser.add_argument('--no-merge', action='store_true',
                    help='Do not use /merge Github PR reference')
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

    exit_code = 0
    tmpdir = tempfile.mkdtemp()
    try:
        git = GitCli(tmpdir)
        githubappcli = GithubAppCli(github_app_id, github_private_key,
                                    github_installation_id)
        github_token = githubappcli.get_token()
        github_url = 'https://x-access-token:{token}@github.com/{repo_owner}/{repo_name}'.format(
            token=github_token,
            repo_owner=args.github_owner,
            repo_name=args.github_component)
        logger.debug('Clone %s' % github_url.replace(github_token, "******"))
        git.clone(github_url)

        repo_owner = args.gitlab_owner
        repo_name = args.gitlab_component

        branch = args.ref
        if args.pull_request:
            branch = 'pr-%s' % args.pull_request

        url = 'https://{repo_owner_nosubgroup}:{token}@{gitlab_url}/{repo_owner}/{repo_name}'.format(
            token=gitlab_token,
            gitlab_url=args.gitlab_url.replace('https://', ''),
            repo_name=repo_name,
            repo_owner=repo_owner,
            repo_owner_nosubgroup=repo_owner.split('/')[0]
        )

        logger.debug('Add remote %s' % repo_owner)
        git.remote_add(repo_owner, url)

        logger.debug('Delete remote branch %s' % branch)
        try:
            git.delete_remote_branch(repo_owner, branch)
        except GitException:
            pass

        if args.pull_request:
            if args.no_merge:
                remote_ref = '+refs/pull/%d/head' % args.pull_request
            else:
                remote_ref = '+refs/pull/%d/merge' % args.pull_request
            ref = 'FETCH_HEAD'

            logger.debug('Fetch {} {}'.format('origin', remote_ref))
            git.fetch('origin', remote_ref)
            logger.debug('Checkout %s' % ref)
            git.checkout(ref, branch=branch)
            git.reset(ref, hard=True)
        else:
            ref = args.ref
            logger.debug('Fetch {} {}'.format('origin', ref))
            git.fetch('origin', ref)
            if args.ref != 'master':
                logger.debug('Checkout %s' % ref)
                git.checkout(ref, branch=branch)

        logger.debug('Commit: {}'.format(git.log(ref)))

        # Before pushing new branch we cancel previous running pipelines
        # with same pr branch name
        gitlabcli = GitlabCli(url='https://gitlab.com', token=gitlab_token)
        gitlabcli.cancel_pipelines(repo_owner, repo_name, branch)

        logger.debug('Push to %s', repo_owner)
        git.push(repo_owner, branch, force=True)
    except Exception as e:
        logger.error('An error occurred: {}'.format(str(e)))
        exit_code = 1
    finally:
        shutil.rmtree(tmpdir)

    return exit_code


if __name__ == '__main__':
    sys.exit(main())
