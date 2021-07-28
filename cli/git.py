import subprocess
import re


class GitException(Exception):
    pass


class GitCli:
    def __init__(self, repo):
        self.repo = repo

    @staticmethod
    def _run(cmd, cwd=None):
        try:
            result = subprocess.run(cmd, shell=True, cwd=cwd, check=True,
                                    stderr=subprocess.STDOUT)
            return result.stdout
        except subprocess.CalledProcessError as e:
            err = {
                "status": str(e),
                "stdout": e.stdout,
                "stderr": e.stderr,
            }
            raise GitException(str(err))

    @staticmethod
    def _get_output(cmd, cwd=None):
        try:
            result = subprocess.check_output(cmd, shell=True, cwd=cwd,
                                             stderr=subprocess.STDOUT)
            return result.decode('utf-8').rstrip('\n')
        except subprocess.CalledProcessError as e:
            raise GitException(str(e))

    def clone(self, source, branch=None, username='fepitre-bot',
              useremail='fepitre-bot@qubes-os.org'):
        if branch:
            repo = 'git clone -b {branch} {src} {dst}'
        else:
            repo = 'git clone {src} {dst}'
        cmd = repo.format(src=source, dst=self.repo, branch=branch)
        cmd_config_name = 'git config user.name "%s"' % username
        cmd_config_email = 'git config user.email %s' % useremail

        self._run(cmd)
        self._run(cmd_config_name, self.repo)
        self._run(cmd_config_email, self.repo)

    def delete_remote_branch(self, source, branch):
        cmd = 'git push {source} --delete {branch}'.format(
            source=source, branch=branch)
        self._run(cmd, self.repo)

    def reset(self, ref, hard=False):
        if hard:
            cmd = 'git reset --hard {ref}'.format(ref=ref)
        else:
            cmd = 'git reset {ref}'.format(ref=ref)
        self._run(cmd, self.repo)

    def fetch(self, source, branch='master'):
        cmd = 'git fetch {source} --tags {branch}'.format(
            source=source, branch=branch)
        self._run(cmd, self.repo)

    def push(self, remote, branch='master', force=False):
        if force:
            cmd = 'git push -f -u {remote} {branch}'.format(
                remote=remote, branch=branch)
        else:
            cmd = 'git push -u {remote} {branch}'.format(
                remote=remote, branch=branch)
        self._run(cmd, self.repo)

    def checkout(self, ref, branch=None):
        if branch:
            cmd = 'git checkout -b {branch} {ref}'.format(
                branch=branch, ref=ref)
        else:
            cmd = 'git checkout {ref}'.format(
                ref=ref)
        self._run(cmd, self.repo)

    def remote_add(self, remote_name, url):
        cmd = 'git remote add {remote_name} {url}'.format(
            remote_name=remote_name, url=url)
        self._run(cmd, self.repo)

    def tags(self, ref):
        cmd = 'git tag --points-at="{ref}"'.format(ref=ref)
        result = self._get_output(cmd, self.repo)
        tags = result.split('\n')
        return tags

    def verify_tag(self, tag, keyrings):
        cmd = 'GNUPGHOME={keyrings} git -c gpg.program=gpg verify-tag --raw {tag}'.format(
            keyrings=keyrings, tag=tag)
        result = self._get_output(cmd, self.repo)
        return re.search(r'\[GNUPG:\] TRUST_(FULLY|ULTIMATE)', result)

    def rev_parse(self, reference):
        cmd = 'git rev-parse --short {reference}'.format(reference=reference)
        result = self._get_output(cmd, self.repo)
        return result

    def merge(self, reference, message):
        cmd = 'git merge {reference} --no-ff -m "{message}"'.format(
                reference=reference, message=message)
        self._run(cmd, self.repo)

    def log(self, reference):
        cmd = 'git log --pretty=format:"%h: %<(80,trunc)%s" -1 {reference}'.format(reference=reference)
        result = self._get_output(cmd, self.repo)
        return result