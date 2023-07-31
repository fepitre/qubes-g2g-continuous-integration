FROM fedora:latest
LABEL maintainer="Frédéric Pierret <frederic.pierret@qubes-os.org>"

RUN dnf -y install \
    ca-certificates \
    createrepo \
    curl \
    debootstrap \
    devscripts \
    docker \
    e2fsprogs \
    gcc-c++ \
    git \
    gpg \
    grub2-tools \
    hunspell \
    jq \
    jekyll \
    libxml2 \
    libxml2-devel \
    libxslt \
    libxslt-devel \
    mock \
    pandoc \
    passwd \
    pbuilder \
    perl-Digest-MD5 \
    perl-Digest-SHA \
    pkg-config \
    podman \
    python3-click \
    python3-debian \
    python3-docker \
    python3-pygithub \
    python3-gobject \
    python3-lxml \
    python3-packaging \
    python3-pathspec \
    python3-pip \
    python3-podman \
    python3-pytest \
    python3-pytest-cov \
    python3-pytest-mock \
    python3-pyyaml \
    python3-requests-mock \
    python3-sh \
    python3-yaml \
    rpm \
    rpm-build \
    rpm-sign \
    rpmdevtools \
    rsync \
    ruby-devel \
    rubygem-bundler \
    rubygems \
    ShellCheck \
    sequoia-sqv \
    sudo \
    tree \
    wget \
    which \
    yum \
    yum-utils

RUN dnf clean all

RUN useradd -m -u 11000 -p "" gitlab-runner -s /bin/bash
RUN echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# debootstrap: workaround until upstream merge it
# https://salsa.debian.org/installer-team/debootstrap/-/merge_requests/26/
RUN sed -i 's@if \! doing_variant fakechroot\; then@if \! doing_variant fakechroot \&\& [ \"$CONTAINER\" \!= docker ]\; then@g' /usr/share/debootstrap/scripts/debian-common /usr/share/debootstrap/scripts/gutsy

RUN cd /tmp && git clone https://github.com/qubesos/qubes-infrastructure-mirrors && cd qubes-infrastructure-mirrors && python3 setup.py build install

RUN sed -i -e 's/^##\(activate = 1\|.*default_sect\|.*legacy_sect\)/\1/' /etc/pki/tls/openssl.cnf

USER gitlab-runner
