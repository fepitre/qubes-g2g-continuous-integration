#!/bin/bash

set -ex -o pipefail

LOCAL_DIR="$(dirname "$0")"
QUBES_IMAGE="${1:-/var/lib/libvirt/images/qubes_4.3_64bit_stable.qcow2}"
SSH_PUB_KEY="${2:-}"
GITLAB_RUNNER="${3:-}"

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

virt-customize -a "${QUBES_IMAGE}" \
  --run-command "sed -i 's|self.netdevs.extend(self.find_devices_of_class(vm, \"02\"))|self.netdevs.extend(sorted(self.find_devices_of_class(vm, \"02\"))[:1])|' /root/extra-files/qubesteststub/__init__.py" \
  --run-command 'cd /root/extra-files/ && python3 setup.py build && python3 setup.py install' \
  --copy-in "$LOCAL_DIR/gitlab_runner.repo:/etc/yum.repos.d/" \
  --copy-in "$LOCAL_DIR/gpgkey:/etc/pki/rpm-gpg/" \
  --copy-in "$LOCAL_DIR/runner-gitlab-runner-49F16C5CC3A0F81F.pub.gpg:/etc/pki/rpm-gpg/" \
  --run-command "sed -i.bak -e '0,/id=\"00_05\.0\"/{ /id=\"00_05\.0\"/{N;N;d;} }' -e 's|id=\"00_03.0.*::p020000\"|id=\"00_01.0-00_00.0\"|' /var/lib/qubes/qubes.xml" \
  --run-command "dnf install --disablerepo=* --enablerepo=fedora --enablerepo=updates --enablerepo=runner_gitlab-runner --setopt=reposdir=/etc/yum.repos.d -y openssh-server dhcp-client git git-lfs gitlab-runner" \
  --run-command "usermod -u 11000 gitlab-runner" \
  --run-command "usermod -aG qubes gitlab-runner" \
  --run-command "groupmod -g 11000 gitlab-runner" \
  --ssh-inject gitlab-runner:file:"$SSH_PUB_KEY" \
  --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
  --mkdir /var/lib/qubes-service/ \
  --touch /var/lib/qubes-service/sshd \
  --copy-in "$LOCAL_DIR/setup-dom0-net.sh":/usr/local/bin/ \
  --copy-in "$LOCAL_DIR/setup-direct-dom0-net.sh":/usr/local/bin/ \
  --chmod 0775:/usr/local/bin/setup-dom0-net.sh \
  --chmod 0775:/usr/local/bin/setup-direct-dom0-net.sh \
  --mkdir /etc/systemd/system/sshd.service.d \
  --copy-in "$LOCAL_DIR/setup-direct-net.service":/etc/systemd/system/ \
  --copy-in "$LOCAL_DIR/custom.conf":/etc/systemd/system/sshd.service.d/ \
  --run-command 'systemctl daemon-reload' \
  --run-command 'systemctl enable sshd' \
  --run-command 'rm -rf /etc/pki/rpm-gpg/gpgkey /etc/pki/rpm-gpg/runner-gitlab-runner-49F16C5CC3A0F81F.pub.gpg /etc/yum.repos.d/gitlab_runner.repo'
