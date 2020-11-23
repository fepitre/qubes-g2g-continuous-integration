generate-fedora.sh#!/bin/bash

set -x

virt-builder fedora-30 \
    --smp 4 \
    --memsize 4096 \
    --size 30G \
    --output /var/lib/libvirt/images/gitlab-runner-fedora.qcow2 \
    --format qcow2 \
    --hostname gitlab-runner-fedora \
    --network \
    --run-command "rm -rf /etc/yum.repos.d/*modular*.repo /etc/yum.repos.d/fedora-cisco-openh264.repo; " \
    --install curl,sudo,passwd,grub2-tools \
    --run-command "curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | bash" \
    --run-command 'useradd -m -p "" gitlab-runner -s /bin/bash' \
    --install gitlab-runner,git,git-lfs,openssh-server \
    --run-command "git lfs install --skip-repo" \
    --ssh-inject gitlab-runner:file:/root/.ssh/id_rsa.pub \
    --run-command "rm -f /root/.ssh/know_hosts" \
    --upload /home/user/ci-keys/id_rsa:/home/gitlab-runner/.ssh/id_rsa \
    --run-command "chown gitlab-runner:gitlab-runner /home/gitlab-runner/.ssh/id_rsa" \
    --run-command "chmod 0600 /home/gitlab-runner/.ssh/id_rsa" \
    --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
    --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
    --run-command "grub2-mkconfig -o /boot/grub2/grub.cfg" \
    --run-command "echo 'DEVICE=eth0' > /etc/sysconfig/network-scripts/ifcfg-eth0" \
    --run-command "echo 'BOOTPROTO=dhcp' >> /etc/sysconfig/network-scripts/ifcfg-eth0" \
    --run-command "sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config" \
    --root-password password:root \
    --install devscripts,debootstrap,pbuilder,git,python3-sh,wget,createrepo,rpm,yum,yum-utils,mock,rsync,rpmdevtools,rpm-build,perl-Digest-MD5,perl-Digest-SHA,python3-pyyaml \
    --install hunspell,pandoc,jq,rubygems,ruby-devel,gcc-c++,pkg-config,libxml2,libxslt,libxml2-devel,libxslt-devel,rubygem-bundler \
    --update
