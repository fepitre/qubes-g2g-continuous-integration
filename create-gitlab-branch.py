#!/usr/bin/python3
import traceback

from cli.cli_git import GitCli, GitException
from cli.cli_github import GithubAppCli
from cli.cli_gitlab import GitlabCli

import os
import argparse
import sys
import logging
import tempfile
import shutil

parser = argparse.ArgumentParser()

parser.add_argument(
    "--gitlab-url", action="store", type=str, required=True, help="Gitlab instance url"
)
parser.add_argument("--ref", action="store", type=str, help="Git reference to use")
parser.add_argument(
    "--pull-request", action="store", type=int, help="Git pullrequest reference to use"
)
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
parser.add_argument(
    "--no-merge", action="store_true", help="Do not use /merge Github PR reference"
)
parser.add_argument(
    "--base-ref", action="store", type=str, help="Base reference for merge"
)
parser.add_argument("--verbose", action="store_true")
parser.add_argument("--debug", action="store_true")

logger = logging.getLogger("create-gitlab-branch")
console_handler = logging.StreamHandler(sys.stderr)
logger.addHandler(console_handler)


class StatusError(Exception):
    pass


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

    if args.pull_request is None and args.ref is None:
        parser.error("Either --ref or --pull-request is required")
    if args.pull_request is not None and args.ref is not None:
        parser.error("Only one of --ref or --pull-request can be used")

    github_app_id = os.getenv("GITHUB_APP_ID")
    pem_file_path = os.getenv("PEM_FILE_PATH")
    github_installation_id = os.getenv("GITHUB_INSTALLATION_ID")
    gitlab_token = os.getenv("GITLAB_API_TOKEN")
    github_token = os.getenv("GITHUB_API_TOKEN")
    github_project = f"{args.github_owner}/{args.github_component}"
    github_appcli = None
    github_ref = None
    tmpdir = tempfile.mkdtemp()
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
        github_appcli = GithubAppCli(
            github_app_id, github_private_key, github_installation_id
        )

        git = GitCli(tmpdir)
        github_token = github_appcli.get_token()
        github_url = (
            "https://x-access-token:{token}@github.com/{repo_owner}/{repo_name}".format(
                token=github_token,
                repo_owner=args.github_owner,
                repo_name=args.github_component,
            )
        )
        logger.debug("Clone %s" % github_url.replace(github_token, "******"))
        git.clone(github_url)

        repo_owner = args.gitlab_owner
        repo_name = args.gitlab_component
        if not args.no_merge and not args.base_ref:
            raise InternalError("Missing base reference for merge")

        branch = args.ref
        if args.pull_request:
            branch = "pr-%s" % args.pull_request

        url = "https://{repo_owner_nosubgroup}:{token}@{gitlab_url}/{repo_owner}/{repo_name}".format(
            token=gitlab_token,
            gitlab_url=args.gitlab_url.replace("https://", ""),
            repo_name=repo_name,
            repo_owner=repo_owner,
            repo_owner_nosubgroup=repo_owner.split("/")[0],
        )

        logger.debug("Add remote %s" % repo_owner)
        git.remote_add(repo_owner, url)

        logger.debug("Delete remote branch %s" % branch)
        try:
            git.delete_remote_branch(repo_owner, branch)
        except GitException:
            pass

        if args.pull_request:
            head_ref = "+refs/pull/%d/head" % args.pull_request
            logger.debug("Fetch {} {} (HEAD reference)".format("origin", head_ref))
            git.fetch("origin", head_ref)
            head_sha = git.rev_parse("FETCH_HEAD")
            github_ref = head_sha

            if not args.no_merge:
                base_sha = None
                base_ref = args.base_ref
                try:

                    logger.debug(
                        "Fetch {} {} (base reference)".format("origin", base_ref)
                    )
                    git.fetch("origin", base_ref)
                    base_sha = git.rev_parse("FETCH_HEAD")

                    logger.debug("Checkout %s (base reference)" % base_ref)
                    git.checkout(base_sha, branch=branch)
                    git.reset(base_sha, hard=True)
                    git.merge(head_sha, message=f"Merge {head_sha} into {base_sha}")
                except Exception:
                    if base_sha:
                        msg = f"Failed to merge {head_sha[:8]} into {base_sha[:8]}"
                    else:
                        msg = f"Failed to merge {head_sha[:8]} into {base_ref}"
                    raise StatusError(msg)
            else:
                logger.debug("Checkout %s (HEAD reference)" % head_sha)
                git.checkout(head_sha, branch=branch)
                git.reset(head_sha, hard=True)
        else:
            github_ref = args.ref
            logger.debug("Fetch {} {}".format("origin", github_ref))
            git.fetch("origin", github_ref)
            if args.ref != "master":
                logger.debug("Checkout %s" % github_ref)
                git.checkout(github_ref, branch=branch)

        logger.debug("Commit: {}".format(git.log(github_ref)))

        # Before pushing new branch we cancel previous running pipelines
        # with same pr branch name
        gitlabcli = GitlabCli(url="https://gitlab.com", token=gitlab_token)
        gitlabcli.cancel_pipelines(repo_owner, repo_name, branch)

        logger.debug("Push to %s", repo_owner)
        git.push(repo_owner, branch, force=True)
        exit_code = 0
    except StatusError as e:
        logger.error(f"StatusError: {str(e)}")
        if github_appcli and github_ref:
            logger.debug(f"Submitting PR status (ref={github_ref},status='failed')")
            result = github_appcli.submit_commit_status(
                repo_name=github_project,
                commit_sha=github_ref,
                status="failure",
                description=str(e),
            )
            if result.status_code > 400:
                logger.error(
                    f"Failed to send PR status: {result.text} (status-code={result.status_code})"
                )
    except InternalError as e:
        logger.error(f"InternalError: {str(e)}")
        exit_code = 1
    except Exception as e:
        logger.error(f"GeneralError: {str(e)}")
        print(traceback.print_exception(*sys.exc_info()))
        exit_code = 2
    finally:
        shutil.rmtree(tmpdir)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
