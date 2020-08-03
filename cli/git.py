import subprocess
import re


class GitCli:
    def __init__(self, repo):
        self.repo = repo

    def clone(self, source, branch='master'):
        result = subprocess.run('git clone -q -b {branch} {src} {dst}'.format(
            src=source, dst=self.repo, branch=branch), shell=True)

        return result.returncode, result.stdout, result.stderr

    def fetch(self, source, branch='master'):
        result = subprocess.run('git fetch -q {source} --tags {branch}'.format(
            source=source, branch=branch), shell=True, cwd=self.repo)

        return result.returncode, result.stdout, result.stderr

    def push(self, remote, branch='master', force=False):
        if force:
            cmd = 'git push -f -q -u {remote} {branch}'.format(
                remote=remote, branch=branch)
        else:
            cmd = 'git push -q -u {remote} {branch}'.format(
                remote=remote, branch=branch)
        result = subprocess.run(cmd, shell=True, cwd=self.repo)

        return result.returncode, result.stdout, result.stderr

    def checkout(self, ref, branch=None):
        if branch:
            cmd = 'git checkout -b {branch} -q {ref}'.format(
                branch=branch, ref=ref)
        else:
            cmd = 'git checkout -q {ref}'.format(
                ref=ref)
        result = subprocess.run(cmd, shell=True, cwd=self.repo)

        return result.returncode, result.stdout, result.stderr

    def remote_add(self, remote_name, url):
        result = subprocess.run('git remote add {remote_name} {url}'.format(
            remote_name=remote_name, url=url), shell=True, cwd=self.repo)

        return result.returncode, result.stdout, result.stderr

    def tags(self, ref):
        tags = subprocess.check_output(
            'git tag --points-at="{ref}"'.format(ref=ref),
            shell=True, cwd=self.repo).decode('utf-8').rstrip('\n').split('\n')

        return tags

    def verify_tag(self, tag, keyrings):
        cmd = 'GNUPGHOME={keyrings} git -c gpg.program=gpg verify-tag --raw {tag}'.format(
            keyrings=keyrings, tag=tag)

        result = subprocess.check_output(
            cmd, shell=True, cwd=self.repo, stderr=subprocess.STDOUT).decode('utf-8')

        return re.search(r'\[GNUPG:\] TRUST_(FULLY|ULTIMATE)', result)
