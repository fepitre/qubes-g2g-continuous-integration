FROM fedora:latest
LABEL maintainer="Frédéric Pierret <frederic.pierret@qubes-os.org>"

RUN dnf -y update
RUN dnf -y install git curl sudo passwd grub2-tools devscripts debootstrap \
  pbuilder git python3-sh wget createrepo rpm yum yum-utils mock rsync \
  rpmdevtools rpm-build perl-Digest-MD5 perl-Digest-SHA python3-pyyaml \
  hunspell pandoc jq rubygems ruby-devel gcc-c++ pkg-config libxml2 libxslt \
  libxml2-devel libxslt-devel rubygem-bundler jekyll ShellCheck pylint
RUN dnf clean all

RUN useradd -m -p "" gitlab-runner -s /bin/bash
RUN echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# debootstrap: workaround until upstream merge it
# https://salsa.debian.org/installer-team/debootstrap/-/merge_requests/26/
RUN sed -i 's@if \! doing_variant fakechroot\; then@if \! doing_variant fakechroot \&\& [ \"$CONTAINER\" \!= docker ]\; then@g' /usr/share/debootstrap/scripts/debian-common

USER gitlab-runner
