FROM debian:bullseye-slim
MAINTAINER Frédéric Pierret <frederic@invisiblethingslab.com>

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -qy update \
    && apt-get install -y sudo git nginx python3-flask python3-jwt python3-github python3-gitlab \
        python3-dateutil uwsgi uwsgi-plugin-python3 nginx-full curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/lists/* \
    && apt-get clean autoclean

# Create user "user" and home dir
RUN useradd -m user

# Copy local dir inside docker
COPY . /home/user/qubes-g2g-continuous-integration

# Clone qubes-builder-github
RUN git clone -b builderv2 https://github.com/fepitre/qubes-builder-github /home/user/qubes-builder-github

# Inject gitlabci webhook service
RUN cp /home/user/qubes-g2g-continuous-integration/services/gitlabci.py /home/user/qubes-builder-github/webhooks/services/
RUN echo '{"services": ["gitlabci"]}' > /home/user/qubes-builder-github/webhooks/webhooks.conf

# Copy RPC and tools in local bin.
RUN cp /home/user/qubes-g2g-continuous-integration/qubes-rpc/gitlabci.G2G \
        /home/user/qubes-g2g-continuous-integration/tools/g2g-wol-runners \
        /usr/local/bin/
RUN chmod +x /usr/local/bin/gitlabci.G2G /usr/local/bin/g2g-wol-runners

# Copy simple nginx conf
RUN cp /home/user/qubes-g2g-continuous-integration/docker/nginx.conf /etc/nginx/nginx.conf

# Fix permissions and missing dir for uwsgi
RUN mkdir /var/run/webhooks
RUN chown -R user:www-data /var/run/webhooks
RUN sed -i 's/gid = nginx/gid = www-data/g' /home/user/qubes-builder-github/webhooks/webhooks.ini

# Create log directory
RUN mkdir -p /home/user/gitlab-ci-g2g-logs

ENV GITLABCI_CONFIG /home/user/gitlab-ci-g2g/gitlabci
ENV WEBHOOKS_CONFIG /home/user/qubes-builder-github/webhooks/webhooks.conf

EXPOSE 80
WORKDIR /home/user/qubes-builder-github/webhooks

CMD ["/home/user/qubes-g2g-continuous-integration/docker/entrypoint.sh"]

