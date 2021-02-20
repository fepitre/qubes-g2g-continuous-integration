import requests
import time
import dateutil.parser
import jwt

from datetime import datetime, timezone
from github import Github


class GithubAppCli:
    def __init__(self, app_id, private_key, installation_id):
        self.app_id = app_id
        self.private_key = private_key
        self.installation_id = installation_id

        self.token = None
        self.expires_at = 0

    def get_jwt(self):
        payload = {
            "iat": int(time.time()),
            "exp": int(time.time()) + (9 * 60),
            "iss": self.app_id,
        }
        encoded = jwt.encode(payload, self.private_key, algorithm="RS256")
        bearer_token = encoded.decode("utf-8")

        return bearer_token

    def gen_token(self):
        bearer_token = self.get_jwt()
        url = 'https://api.github.com/app/installations/{}/access_tokens' \
            .format(self.installation_id)
        r = requests.post(url, headers={
            'Authorization': 'Bearer {}'.format(bearer_token),
            'Accept': 'application/vnd.github.v3+json',
        })
        if r.status_code != 201:
            raise Exception("GithubApp: Failed to generate token: {}".format(
                r.json()['message']))
        resp = r.json()
        self.token = resp['token']
        self.expires_at = dateutil.parser.parse(resp['expires_at'])

    def get_token(self):
        if not self.token:
            self.gen_token()
        else:
            delta = datetime.now(timezone.utc) - self.expires_at
            if delta.total_seconds() <= 0:
                self.gen_token()

        return self.token

    def submit_commit_status(self, repo_name, commit_sha, status,
                             pipeline_status, url, description=None):
        api_url = 'https://api.github.com/repos/{}/statuses/{}'.format(
            repo_name,
            commit_sha
        )
        if not description:
            description = "Pipeline: %s" % pipeline_status
        r = requests.post(api_url, json={
            'state': status,
            'description': description,
            'target_url': url,
            'context': "continuous-integration/pullrequest",
        }, headers={
            'Authorization': 'token {}'.format(self.get_token()),
            'Accept': 'application/vnd.github.v3+json'
        })
        return r.status_code


class GithubCli:
    def __init__(self, token):
        self.token = token
        self.gi = Github(self.token)

    def get_repo(self, owner, project_name):
        return self.gi.get_repo('%s/%s' % (owner, project_name))

    def get_pull_request(self, owner, project_name, pull_request_id):
        project = self.get_repo(owner, project_name)
        if project:
            for pr in project.get_pulls():
                if pr.number == pull_request_id:
                    return pr

    def get_branch(self, owner, project_name, branch):
        project = self.get_repo(owner, project_name)
        if project:
            try:
                return project.get_branch(branch)
            except:
                return None

    @staticmethod
    def set_status(project, sha, status, pipeline_status, url):
        project.get_commit(sha).create_status(
            state=status,
            target_url=url,
            description="Pipeline: %s" % pipeline_status,
            context="continuous-integration/pullrequest"
        )
