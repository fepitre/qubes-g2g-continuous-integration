# QubesOS GitLab CI Runner

Ansible playbook to deploy a GitLab CI runner on Qubes OS.

## Architecture

- **`fedora-42-xfce`** (`gitlab-ci-dvm`, `gitlab-ci-dvm-fepitre-bot`) — disposable templates for CI job cages
- **`fedora-42-xfce`** (`gitlab-ci-admin`, ...) — runner admin AppVMs running `gitlab-runner`

Runner admin AppVMs connect to GitLab and dispatch jobs into disposable qubes via the custom executor scripts (`prepare.sh`, `run.sh`, `cleanup.sh`).

## Prerequisites

- dom0 with `qubes-ansible` and the `qubes` connection plugin available
- `gitlab-runner-linux-amd64` binary copied to `/tmp/` in dom0 (dom0 has no internet access)
- A vars file with runner tokens (see `group_vars/all.yml` for the full variable reference)

## Usage

Run from dom0:

```bash
cd runner/qubesos/ansible
ansible-playbook playbooks/main.yml -e @/path/to/vars.yml
```

Run only specific parts via tags:

| Tag | What it does |
|-----|-------------|
| `executor_template` | Install and configure `fedora-42-xfce` |
| `runner_admin_template` | Install openssh-server into `fedora-42-xfce` |
| `ci_dvm` | Create and configure `gitlab-ci-dvm` |
| `runner_admin` | Create runner AppVMs, register runners, deploy keys |
| `policy` | Install RPC policy in dom0 |

## SSH access to runner AppVMs

From a machine that can reach dom0 (e.g. `10.13.0.12`), add to `~/.ssh/config`:

```
Host gitlab-ci-griotte gitlab-ci-amarena
    User user
    ProxyCommand ssh user@10.13.0.12 "qvm-run --pass-io -u user %h 'socat - TCP4:localhost:22'"
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

Authorized keys are deployed via `runner_admin_authorized_keys` in your vars file.

## Key variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ci_executor_template` | `fedora-42-xfce` | Template for CI job cages |
| `runner_admin_template` | `fedora-42-xfce` | Template for runner admin AppVMs |
| `ci_dvm_name` | `gitlab-ci-dvm` | Disposable template name |
| `runner_admin_names` | see `group_vars/all.yml` | List of runner AppVMs with tokens |
| `runner_admin_authorized_keys` | `[]` | SSH public keys for runner AppVMs |
