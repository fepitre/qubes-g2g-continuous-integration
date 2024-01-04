#!/bin/bash

set -x

virt-builder fedora-37 \
    --smp 4 \
    --memsize 4096 \
    --size 80G \
    --output /var/lib/libvirt/images/gitlab-runner-fedora.qcow2 \
    --format qcow2 \
    --hostname gitlab-runner-fedora \
    --network \
    --run-command "rm -rf /etc/yum.repos.d/*modular*.repo /etc/yum.repos.d/fedora-cisco-openh264.repo; " \
    --copy-in "gitlab_runner.repo:/etc/yum.repos.d/" \
    --copy-in "packages-gitlab-gpg-key.pub.gpg:/etc/pki/rpm-gpg/" \
    --copy-in "runner-gitlab-runner-4C80FB51394521E9.pub.gpg:/etc/pki/rpm-gpg/" \
    --copy-in "runner-gitlab-runner-49F16C5CC3A0F81F.pub.gpg:/etc/pki/rpm-gpg/" \
    --install gitlab-runner,git,git-lfs,openssh-server,curl,sudo,passwd,grub2-tools,devscripts,debootstrap,pbuilder,python3-sh,wget,createrepo,rpm,yum,yum-utils,mock,rsync,rpmdevtools,rpm-build,perl-Digest-MD5,perl-Digest-SHA,python3-pyyaml,hunspell,pandoc,jq,rubygems,ruby-devel,gcc-c++,pkg-config,libxml2,libxslt,libxslt-devel,rubygem-bundler,python3-pip,cryptsetup,python3-packaging,createrepo_c,devscripts,gpg,python3-pyyaml,docker,python3-docker,podman,python3-podman,reprepro,docker-compose,rpm-sign,xterm-resize,vim,python3-pathspec,python3-lxml,kernel-devel,tree,python3-jinja2-cli,pacman,m4,asciidoc,rsync \
    --run-command "dnf update -y kernel kernel-devel" \
    --run-command "git lfs install --skip-repo" \
    --ssh-inject gitlab-runner:file:/root/.ssh/id_rsa_gitlab.pub \
    --run-command "usermod -u 11000 gitlab-runner" \
    --run-command "groupmod -g 11000 gitlab-runner" \
    --run-command "rm -f /root/.ssh/know_hosts" \
    --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
    --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
    --run-command "grub2-mkconfig -o /boot/grub2/grub.cfg" \
    --run-command "echo 'DEVICE=eth0' > /etc/sysconfig/network-scripts/ifcfg-eth0" \
    --run-command "echo 'BOOTPROTO=dhcp' >> /etc/sysconfig/network-scripts/ifcfg-eth0" \
    --run-command "sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config" \
    --run-command "usermod -aG docker gitlab-runner" \
    --run-command "systemctl enable docker" \
    --run-command "cd /tmp && git clone https://github.com/qubesos/qubes-infrastructure-mirrors && cd qubes-infrastructure-mirrors && python3 setup.py build install" \
    --run-command "sed -i -e 's/^##\(activate = 1\|.*default_sect\|.*legacy_sect\)/\1/' /etc/pki/tls/openssl.cnf" \
    --root-password password:root \
    --update
