qubes-g2g-continuous-integration
===

Repository for creating Gitlab CI/CD pipelines from GitHub.

Inspired from [signature-checker](https://github.com/marmarek/signature-checker) made by
Marek Marczykowski-Górecki <marmarek@invisiblethingslab.com>.

### Installation

##### Docker

Build the container image:

```bash
$ sudo docker build -f docker/Dockerfile -t gitlab-ci-g2g .
```

All the setup assumes that sensitive data are located /home/user/gitlab-ci-g2g inside the container. You need to
provide `gitlabci` configuration file, GitHub SSH application key and `wol_token` (if applies) inside your local
directory `/path/to/my/sensitive/data` which will be mounted in container as `/home/user/gitlab-ci-g2g`:
```bash
$ sudo docker run -d -p 8080:80 \
    -v /var/log/nginx:/var/log/nginx \
    -v /path/to/my/log/for/g2g:/home/user/gitlab-ci-g2g-logs \
    -v /path/to/my/sensitive/data:/home/user/gitlab-ci-g2g:ro \
    gitlab-ci-g2g
```

You will find the log of `gitlab.G2G` at /path/to/my/log/for/g2g/g2g.log and the log for `uwsgi` service at
/path/to/my/log/for/g2g/webhooks.log. Nginx logs can be found in `/var/log/nginx` directory.

You can leverage systemd service file by copying `docker/docker.gitlab-ci-g2g.service` in `/etc/systemd/system` and
adapt the path for logs and sensitive data.

##### WIP: AppVM

Example CONFIG:
```
[DEFAULT]
home = /home/user/qubes-g2g-continuous-integration
#pem_file_path = ...
#github_installation_id = ...
#gitlab_api_token = ...
#github_api_token = ...
callback = "/usr/local/bin/my_script_1 /usr/local/bin/my_script_2 ..."

[QubesOS]
user_whitelist = fepitre marmarek woju
repo_whitelist = ...
github_app_id = ...
```

RPC installation:
```
ln -sf "$PWD/qubes-rpc/gitlabci.G2G" /rw/usrlocal/etc/qubes-rpc/
```

### How-to

Supported command in PR comments:
```
PipelineRefresh             <- Refresh pipeline status
PipelineRetry               <- Retry pipeline with '/merge' ref (current branch merged into target branch)
PipelineRetry+head          <- Retry pipeline with '/head' ref (current branch)
```
