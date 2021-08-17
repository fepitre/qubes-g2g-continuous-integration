#!/bin/bash

set -x

virt-builder fedora-34 \
    --smp 4 \
    --memsize 4096 \
    --size 30G \
    --output /var/lib/libvirt/images/gitlab-runner-fedora.qcow2 \
    --format qcow2 \
    --hostname gitlab-runner-fedora \
    --network \
    --run-command "rm -rf /etc/yum.repos.d/*modular*.repo /etc/yum.repos.d/fedora-cisco-openh264.repo; " \
    --install git,git-lfs,openssh-server,curl,sudo,passwd,grub2-tools,devscripts,debootstrap,pbuilder,python3-sh,wget,createrepo,rpm,yum,yum-utils,mock,rsync,rpmdevtools,rpm-build,perl-Digest-MD5,perl-Digest-SHA,python3-pyyaml,hunspell,pandoc,jq,rubygems,ruby-devel,gcc-c++,pkg-config,libxml2,libxslt,libxml2-devel,libxslt-devel,rubygem-bundler,python3-pip,cryptsetup \
    --run-command "curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64" \
    --run-command "chmod +x /usr/local/bin/gitlab-runner" \
    --run-command 'useradd -m -p "" gitlab-runner -s /bin/bash' \
    --run-command "git lfs install --skip-repo" \
    --ssh-inject gitlab-runner:file:/root/.ssh/id_rsa.pub \
    --run-command "rm -f /root/.ssh/know_hosts" \
    --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
    --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
    --run-command "grub2-mkconfig -o /boot/grub2/grub.cfg" \
    --run-command "echo 'DEVICE=eth0' > /etc/sysconfig/network-scripts/ifcfg-eth0" \
    --run-command "echo 'BOOTPROTO=dhcp' >> /etc/sysconfig/network-scripts/ifcfg-eth0" \
    --run-command "sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config" \
    --root-password password:root
