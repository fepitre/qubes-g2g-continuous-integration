#/bin/bash
set -ex -o pipefail

# attach second kvm card to dom0
echo 0000:02:00.0 > /sys/bus/pci/drivers/pciback/unbind
MODALIAS="$(cat /sys/bus/pci/devices/0000:02:00.0/modalias)"
MOD="$(modprobe -R "$MODALIAS" | head -n 1)"
echo 0000:02:00.0 > "/sys/bus/pci/drivers/$MOD/bind"

# start dhclient
dhclient enp2s0