FROM fedora:32

RUN dnf install -y dnf-plugins-core
RUN dnf copr -y enable fepitre/fedora
RUN dnf install -y reprotest

COPY qubes-dom0.repo /etc/yum.repos.d/
COPY RPM-GPG-KEY-qubes-4-primary /etc/pki/rpm-gpg/
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-qubes-4-primary
RUN ln -s /etc/pki/rpm-gpg/RPM-GPG-KEY-qubes-4-primary /etc/pki/rpm-gpg/RPM-GPG-KEY-qubes-4.1-primary

RUN dnf makecache -y

# cleanup
RUN dnf clean all
