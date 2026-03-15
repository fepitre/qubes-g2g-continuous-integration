#!/bin/bash

set -eux

LOCAL_DIR="$(dirname "$0")"
SSH_PUB_KEY="${1:-}"

if [ -z "${SSH_PUB_KEY}" ] || [ ! -e "${SSH_PUB_KEY}"]; then
  if [ -e /home/gitlab-runner/.ssh/id_ed25519.pub ]; then
    SSH_PUB_KEY=/home/gitlab-runner/.ssh/id_ed25519.pub
  elif [ -e /var/lib/gitlab-runner/.ssh/id_ed25519.pub ]; then
    SSH_PUB_KEY=/var/lib/gitlab-runner/.ssh/id_ed25519.pub
  elif [ -e "$LOCAL_DIR"/id_ed25519.pub ]; then
    SSH_PUB_KEY="$LOCAL_DIR"/id_ed25519.pub
  else
    echo "Cannot find gitlab-runner's SSH public key."
    exit 1
  fi
fi

PACKAGES="$(tr '\n' ',' < "${LOCAL_DIR}/packages_fedora.list")"
PACKAGES="${PACKAGES%,}"

virt-builder fedora-42 \
    --smp 4 \
    --memsize 4096 \
    --size 80G \
    --output /var/lib/libvirt/images/gitlab-runner-fedora.qcow2 \
    --format qcow2 \
    --hostname gitlab-runner-fedora \
    --network \
    --run-command "rm -rf /etc/yum.repos.d/*modular*.repo /etc/yum.repos.d/fedora-cisco-openh264.repo; " \
    --copy-in "gitlab_runner.repo:/etc/yum.repos.d/" \
    --copy-in "gpgkey:/etc/pki/rpm-gpg/" \
    --copy-in "runner-gitlab-runner-49F16C5CC3A0F81F.pub.gpg:/etc/pki/rpm-gpg/" \
    --copy-in "eth0.nmconnection:/etc/NetworkManager/system-connections/" \
    --run-command "chmod 600 /etc/NetworkManager/system-connections/eth0.nmconnection" \
    --install "$PACKAGES" \
    --run-command "dnf update -y kernel kernel-devel" \
    --run-command "git lfs install --skip-repo" \
    --ssh-inject gitlab-runner:file:"$SSH_PUB_KEY" \
    --run-command "usermod -u 11000 gitlab-runner" \
    --run-command "groupmod -g 11000 gitlab-runner" \
    --run-command "rm -f /root/.ssh/know_hosts" \
    --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
    --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
    --run-command "grub2-mkconfig -o /boot/grub2/grub.cfg" \
    --run-command "sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config" \
    --run-command "usermod -aG docker gitlab-runner" \
    --run-command "systemctl enable docker" \
    --run-command "cd /tmp && git clone https://github.com/qubesos/qubes-infrastructure-mirrors && cd qubes-infrastructure-mirrors && python3 setup.py build install" \
    --run-command "sed -i -e 's/^##\(activate = 1\|.*default_sect\|.*legacy_sect\)/\1/' /etc/pki/tls/openssl.cnf" \
    --root-password password:root \
    --update
