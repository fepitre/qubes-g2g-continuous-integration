# GitLab Runner Setup

### 1. Installation

#### 1.1. Create Management Qube
Create a qube named `gitlab-ci-admin`. This qube will host all the GitLab Runner configurations and manage the creation of disposable qubes for Continuous Integration (CI) jobs.

#### 1.2. Create Disposable Qube Template
Create a disposable qube template named `gitlab-ci-dvm`. This template will be used to create qubes that host the CI jobs.

> **Note:** Ensure that `gitlab-runner` is installed in the template used for `gitlab-ci-dvm`. This is crucial for performing necessary functions like uploading artifacts.

### 2. dom0 Setup

#### 2.1. Copy Policy File
Copy the policy file `50-gitlab-ci.policy` to `/etc/qubes/policy`.

#### 2.2. Tagging Disposable Qubes
To allow the disposable qube to use the `builderv2` QubesExecutor in the RPC policy, automatically tag them using the following command:
```bash
qvm-features gitlab-ci-dvm tag-created-vm-with disp-for-executor
```

### 3. gitlab-ci-admin Setup

#### 3.1. Clone Project Repository
Clone your project repository into the `/opt` directory in the `gitlab-ci-admin` qube.

#### 3.2. Install GitLab Runner
Install GitLab Runner by following the instructions from the official documentation: [GitLab Runner Installation Guide](https://docs.gitlab.com/runner/install/linux-repository.html). Install it in `/usr/local/bin/`.

#### 3.3. Create `gitlab-runner` User
Create a user named `gitlab-runner` for running the GitLab Runner service.

#### 3.4. Register GitLab Runner
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
  builds_dir = "/home/user/builds"
  cache_dir = "/home/user/cache"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
  [runners.custom]
    prepare_exec = "/opt/qubes-g2g-continuous-integration/runner/qubesos/prepare.sh"
    run_exec = "/opt/qubes-g2g-continuous-integration/runner/qubesos/run.sh"
    cleanup_exec = "/opt/qubes-g2g-continuous-integration/runner/qubesos/cleanup.sh"
```

Move this `config.toml` file to `/rw/config/gitlab-runner/config.toml`.

#### 3.5. Setup systemd Service
Copy the `gitlab-runner.service` file to `/usr/local/lib/systemd/system/`.

### 4. gitlab-ci-dvm Setup

#### 4.1. Install GitLab Runner
Install GitLab Runner by following the instructions from the official documentation: [GitLab Runner Installation Guide](https://docs.gitlab.com/runner/install/linux-repository.html). Install it in `/usr/local/bin/`.

Ensure to have `docker` installed and started.

Further steps for `gitlab-ci-dvm` can be specified as needed, including any specific configurations or scripts required for CI job execution.
