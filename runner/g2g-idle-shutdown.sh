#!/bin/bash

set -ex

rm -f /tmp/.started && echo > /tmp/.started

# just in case...
sleep 1

# -2 == remove header/footer of journalctl
while [ "$(( $(find /tmp/.started -mmin -180 | wc -l) + $(journalctl -t gitlab-runner --no-hostname -r --grep 'Submitting job to coordinator' --since '3 hours ago' | wc -l) - 2 + $(find /tmp/.started /var/lib/openqa/pool/ -mmin -180 | wc -l) ))" != "0" ]; do
    sleep 15m
done

date >> /var/log/shutdown.log
/usr/sbin/shutdown
