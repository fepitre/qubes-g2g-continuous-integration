#!/bin/bash

set -ex -o pipefail

LOCAL_DIR="$(dirname "$0")"
SSH_PUB_KEY="${1:-}"
GITLAB_RUNNER="${2:-}"

if [ -z "${SSH_PUB_KEY}" ] || [ ! -e "${SSH_PUB_KEY}" ]; then
  if [ -e /home/gitlab-runner/.ssh/id_rsa.pub ]; then
    SSH_PUB_KEY=/home/gitlab-runner/.ssh/id_rsa.pub
  elif [ -e /var/lib/gitlab-runner/.ssh/id_rsa.pub ]; then
    SSH_PUB_KEY=/var/lib/gitlab-runner/.ssh/id_rsa.pub
  elif [ -e "$LOCAL_DIR"/id_rsa.pub ]; then
    SSH_PUB_KEY="$LOCAL_DIR"/id_rsa.pub
  else
    echo "Cannot find gitlab-runner's SSH public key."
    exit 1
  fi
fi

if [ -z "${GITLAB_RUNNER}" ]; then
  # Download gitlab-runner
  # FIXME: check signature
  GITLAB_RUNNER_VERSION=$(curl -s https://gitlab-runner-downloads.s3.amazonaws.com/latest/index.html \
    | grep -oP '(?<=href=")[^"]+(?=")' \
    | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' \
    | head -1)

  GITLAB_RUNNER="$(mktemp -d)/gitlab-runner"

  wget -o "${GITLAB_RUNNER}" https://gitlab-runner-downloads.s3.amazonaws.com/v${GITLAB_RUNNER_VERSION}/binaries/gitlab-runner-linux-amd64
fi

virt-customize -a /var/lib/libvirt/images/qubes_4.3_64bit_stable.qcow2 \
  --run-command "sed -i.bak -e '0,/id=\"00_05\.0\"/{ /id=\"00_05\.0\"/{N;N;d;} }' -e 's|id=\"00_03.0.*::p020000\"|id=\"00_01.0-00_00.0\"|' /var/lib/qubes/qubes.xml" \
  --run-command "useradd -m -u 11000 gitlab-runner" \
  --ssh-inject gitlab-runner:file:"$SSH_PUB_KEY" \
  --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
  --copy-in ${GITLAB_RUNNER}:/usr/local/bin/ \
  --mkdir /var/lib/qubes-service/ \
  --touch /var/lib/qubes-service/sshd \
  --run-command "dnf install --disablerepo=* --enablerepo=fedora --enablerepo=updates --setopt=reposdir=/etc/yum.repos.d -y openssh-server dhcp-client" \
  --copy-in "$LOCAL_DIR/setup-dom0-net.sh":/usr/local/bin/ \
  --copy-in "$LOCAL_DIR/setup-direct-dom0-net.sh":/usr/local/bin/ \
  --chmod 0755:/usr/local/bin/setup-dom0-net.sh \
  --chmod 0755:/usr/local/bin/setup-direct-dom0-net.sh \
  --mkdir /etc/systemd/system/sshd.service.d \
  --copy-in "$LOCAL_DIR/setup-direct-net.service:/etc/systemd/system/"\
  --run-command 'systemctl daemon-reload' \
  --run-command 'systemctl enable sshd'

#  --copy-in "$LOCAL_DIR/custom.conf":/etc/systemd/system/sshd.service.d/ \
