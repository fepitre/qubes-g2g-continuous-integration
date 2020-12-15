FROM debian:buster

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install reprotest
RUN apt-get -y install disorderfs faketime locales-all sudo util-linux

# Add qubes-builder (artifacts) and Qubes repositories
COPY qubes-builder.list /etc/apt/sources.list.d/qubes-builder.list
COPY qubes-debian-r4.asc /tmp
RUN apt-key add - < /tmp/qubes-debian-r4.asc

# cleanup
RUN rm -rf /var/cache/apt
