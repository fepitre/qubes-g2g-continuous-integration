# GitLab Runner Setup

### Installation

1. **Install GitLab Runner**
   Follow the instructions for installing GitLab Runner from the official documentation: [GitLab Runner Installation Guide](https://docs.gitlab.com/runner/install/linux-repository.html). Install it in a template qube, such as `gitlab-ci-template`.

2. **Create Management Qube**
   Create a qube named `gitlab-ci-admin`. This qube will host all the GitLab Runner configurations and manage the creation of disposable qubes for Continuous Integration (CI) jobs.

3. **Create Disposable Qube Template**
   Create a disposable qube template named `gitlab-ci-dvm` based on the `gitlab-ci-template`. This will be used to create qubes that host the CI jobs.

> **Remark**: It is essential to have `gitlab-runner` installed in the template used for `gitlab-ci-dvm`. This ensures that necessary functions, such as uploading artifacts, can be performed effectively.

### dom0 Setup

Copy the policy file `50-gitlab-ci.policy` to `/etc/qubes/policy`.

In order to allow disposable qube to use `builderv2` QubesExecutor in RPC policy, we will tag them automatically:
```bash
qvm-features gitlab-ci-dvm tag-created-vm-with disp-for-executor
```

### gitlab-ci-admin Setup

1. **Clone Project Repository**
   Clone your project repository to the `/opt` directory in the `gitlab-ci-admin` qube.

2. **Register GitLab Runner**
   Register the current machine as a custom runner with your GitLab instance. Follow the registration steps provided by GitLab. After registration, edit the `/etc/gitlab-runner/config.toml` file to include the following configuration:

   ```toml
   concurrent = 4
   check_interval = 0

   [session_server]
     session_timeout = 1800

   [[runners]]
     name = "myAwesomeRunner"
     token = "thisisNOTtheREGISTRATIONtoken"
     url = "https://gitlab.com"
     executor = "custom"
     output_limit = 131072
     builds_dir = "/home/gitlab-runner/builds"
     cache_dir = "/home/gitlab-runner/cache"
     [runners.custom_build_dir]
     [runners.cache]
       [runners.cache.s3]
       [runners.cache.gcs]
     [runners.custom]
       prepare_exec = "/opt/qubes-g2g-continuous-integration/runner/qubesos/prepare.sh"
       run_exec = "/opt/qubes-g2g-continuous-integration/runner/qubesos/run.sh"
       cleanup_exec = "/opt/qubes-g2g-continuous-integration/runner/qubesos/cleanup.sh"
   ```

### gitlab-ci-dvm Setup

Further steps for `gitlab-ci-dvm` can be specified here as needed, such as any specific configurations or scripts that need to be prepared for CI job execution.
