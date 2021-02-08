FROM fedora:latest

RUN dnf install -y dnf-plugins-core
RUN dnf copr -y enable fepitre/fedora
RUN dnf install -y reprotest

COPY qubes-r4.repo /etc/yum.repos.d/
COPY RPM-GPG-KEY-qubes-4-primary /etc/pki/rpm-gpg/
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-qubes-4-primary

# cleanup
RUN dnf clean all
