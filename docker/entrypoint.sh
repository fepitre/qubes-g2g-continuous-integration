#!/bin/bash

set -ex

# uwsgi is daemonized with log
/usr/bin/uwsgi --ini webhooks.ini --daemonize /home/user/gitlab-ci-g2g-logs/webhooks.log

# nginx remains the only process in foreground
/usr/sbin/nginx -g 'daemon off;'

