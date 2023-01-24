FROM fedora:latest
LABEL maintainer="Frédéric Pierret <frederic.pierret@qubes-os.org>"

RUN dnf -y install git curl sudo passwd grub2-tools devscripts debootstrap \
  pbuilder git python3-sh wget createrepo rpm yum yum-utils mock rsync \
  rpmdevtools rpm-build perl-Digest-MD5 perl-Digest-SHA python3-pyyaml \
  hunspell pandoc jq rubygems ruby-devel gcc-c++ pkg-config libxml2 libxslt \
  libxml2-devel libxslt-devel rubygem-bundler jekyll ShellCheck pylint \
  python3-pip python3-gobject e2fsprogs ca-certificates which \
  python3-requests-mock python3-pytest python3-pytest-mock python3-pytest-cov \
  python3-podman python3-yaml python3-click python3-docker podman docker gpg rpm-sign tree \
  python3-pathspec python3-packaging python3-debian python3-lxml
RUN dnf clean all

RUN useradd -m -u 11000 -p "" gitlab-runner -s /bin/bash
RUN echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# debootstrap: workaround until upstream merge it
# https://salsa.debian.org/installer-team/debootstrap/-/merge_requests/26/
RUN sed -i 's@if \! doing_variant fakechroot\; then@if \! doing_variant fakechroot \&\& [ \"$CONTAINER\" \!= docker ]\; then@g' /usr/share/debootstrap/scripts/debian-common /usr/share/debootstrap/scripts/gutsy

RUN cd /tmp && git clone https://github.com/qubesos/qubes-infrastructure-mirrors && cd qubes-infrastructure-mirrors && python3 setup.py build install

RUN sed -i -e 's/^##\(activate = 1\|.*default_sect\|.*legacy_sect\)/\1/' /etc/pki/tls/openssl.cnf

USER gitlab-runner
