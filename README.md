qubes-g2g-continuous-integration
===

Repository for creating Gitlab CI/CD pipelines from Github

Inspired from [signature-checker](https://github.com/marmarek/signature-checker) made by
Marek Marczykowski-Górecki <marmarek@invisiblethingslab.com>.

Example CONFIG:
```
[DEFAULT]
home = /home/user/qubes-g2g-continuous-integration
#pem_file_path = ...
#github_installation_id = ...
#gitlab_api_token = ...
#github_api_token = ...

[QubesOS]
user_whitelist = fepitre marmarek woju
repo_whitelist = ...
github_app_id = ...
```

RPC installation:
```
ln -sf "$PWD/qubes-rpc/gitlabci.G2G" /rw/usrlocal/etc/qubes-rpc/
```

Supported command in PR comments:
```
PipelineRefresh             <- Refresh pipeline status
PipelineRetry               <- Retry pipeline with '/merge' ref (current branch merged into target branch)
PipelineRetry+head          <- Retry pipeline with '/head' ref (current branch)
```