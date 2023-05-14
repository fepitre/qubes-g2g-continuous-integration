#!/bin/bash

set -x

virt-builder debian-11 \
    --size 80G \
    --output /var/lib/libvirt/images/gitlab-runner-debian.qcow2 \
    --format qcow2 \
    --hostname gitlab-runner-debian \
    --run-command "ln -s /dev/sda /dev/vda" \
    --update \
    --run-command "sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list" \
    --run-command "apt-get update" \
    --run-command "DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical DEBCONF_NOWARNINGS=yes apt-get -y -o 'Dpkg::Options::=--force-confnew' full-upgrade" \
    --network \
    --install curl,sudo,coreutils,dpkg-dev,debootstrap \
    --install git,python3-sh,wget,rpm,devscripts,rsync,python3-packaging,createrepo-c,devscripts,gpg,python3-yaml,rpm,docker.io,python3-docker,reprepro,python3-pathspec,mktorrent,openssl,tree,python3-setuptools,python3-lxml \
    --run-command "grub-install /dev/sda" \
    --run-command "curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash" \
    --run-command "curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash" \
    --run-command 'useradd -m -u 11000 -p "" gitlab-runner -s /bin/bash' \
    --install gitlab-runner,git,git-lfs,openssh-server \
    --run-command "git lfs install --skip-repo" \
    --ssh-inject gitlab-runner:file:/root/.ssh/id_rsa_gitlab.pub \
    --run-command "usermod -u 11000 gitlab-runner" \
    --run-command "groupmod -g 11000 gitlab-runner" \
    --run-command "rm -f /root/.ssh/know_hosts" \
    --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
    --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
    --run-command "grub-mkconfig -o /boot/grub/grub.cfg" \
    --run-command "echo 'auto eth0' >> /etc/network/interfaces" \
    --run-command "echo 'allow-hotplug eth0' >> /etc/network/interfaces" \
    --run-command "echo 'iface eth0 inet dhcp' >> /etc/network/interfaces" \
    --root-password password:root
