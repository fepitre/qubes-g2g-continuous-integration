#!/bin/bash

set -x

virt-builder debian-10 \
    --size 30G \
    --output /var/lib/libvirt/images/gitlab-runner-debian.qcow2 \
    --format qcow2 \
    --hostname gitlab-runner-buster \
    --network \
    --install curl,sudo,coreutils,dpkg-dev,debootstrap \
    --install git,python3-sh,wget,createrepo,rpm,yum,yum-utils,mock,devscripts,rsync \
    --update \
    --run-command "grub-install /dev/sda" \
    --run-command "curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash" \
    --run-command "curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash" \
    --run-command 'useradd -m -u 11000 -p "" gitlab-runner -s /bin/bash' \
    --install gitlab-runner,git,git-lfs,openssh-server \
    --run-command "git lfs install --skip-repo" \
    --ssh-inject gitlab-runner:file:/root/.ssh/id_rsa_gitlab.pub \
    --run-command "rm -f /root/.ssh/know_hosts" \
    --upload /home/user/ci-keys/id_rsa:/home/gitlab-runner/.ssh/id_rsa \
    --run-command "chown gitlab-runner:gitlab-runner /home/gitlab-runner/.ssh/id_rsa" \
    --run-command "chmod 0600 /home/gitlab-runner/.ssh/id_rsa" \
    --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
    --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
    --run-command "grub-mkconfig -o /boot/grub/grub.cfg" \
    --run-command "echo 'auto eth0' >> /etc/network/interfaces" \
    --run-command "echo 'allow-hotplug eth0' >> /etc/network/interfaces" \
    --run-command "echo 'iface eth0 inet dhcp' >> /etc/network/interfaces" \
    --root-password password:root
