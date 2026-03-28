# How to setup KVM build server

### Common tools

Debian:

```shell
apt install sudo tmux git vim htop iotop nmon rsync
```

Fedora:

```shell
dnf install sudo tmux git vim htop iotop nmon rsync
```

### Libguestfs & KVM

Debian:

```shell
apt install libguestfs-tools virt-manager virtinst virt-viewer libguestfs-xfs qemu-system libvirt-clients libvirt-daemon-system libosinfo-bin isc-dhcp-client
```

Fedora:

```shell
dnf install libguestfs-tools virt-manager virt-install virt-viewer libguestfs-xfs libosinfo libvirt-daemon-kvm libvirt guestfs-tools dhcp-client
```

For a user to be able to run build in userspace, add it to the `libvirt` and `kvm` groups (see [https://wiki.debian.org/KVM](https://wiki.debian.org/KVM)):

```shell
usermod -aG libvirt kvm user
```

On Debian/Ubuntu, the kernel images in `/boot` are not world-readable by default, which causes `supermin` (used internally by libguestfs) to fail. Make them readable:

```shell
chmod 644 /boot/vmlinuz-*
```

Also ensure `gitlab-runner` can write to the libvirt images directory:

```shell
chgrp libvirt /var/lib/libvirt/images
chmod g+w /var/lib/libvirt/images
```

### Solve MSRs issues

```shell
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf
```

For ignoring and not logging them, do that instead:

```shell
echo "options kvm ignore_msrs=1 report_ignored_msrs=0" > /etc/modprobe.d/kvm.conf
```

# gitlab-runner

### Installation

Install gitlab-runner (see [https://docs.gitlab.com/runner/install/linux-repository.html](https://docs.gitlab.com/runner/install/linux-repository.html)).

Don't forget to add Gitlab CA before the runner registration.

Add `gitlab-runner` to `libvirt` and `kvm` groups.

### Configuration

Clone current project repository to `/opt`.
Ensure that `gitlab-runner` has SSH keys generated.
Its public key (`/home/gitlab-runner/.ssh/id_ed25519.pub`) will be injected inside the ephemeral VM to allow the runner to connect via SSH.
Generate the VM template used for runner jobs by running the script **from its own directory** as the `gitlab-runner` user:

```shell
cd /opt/qubes-g2g-continuous-integration/runner/kvm
sudo -u gitlab-runner bash generate-fedora.sh
```

> **Note:** The script must be run as a non-root user (e.g. `gitlab-runner`). Running it as root causes `passt` (the libguestfs network helper) to drop privileges to `nobody`, which then fails to write its PID file.

This will create the `qcow2` image at `/var/lib/libvirt/images/gitlab-runner-fedora.qcow2`.

Register current machine as `custom` runner to your Gitlab instance and once this is done, edit the file `/etc/gitlab-runner/config.toml` and add the corresponding fields like:
```toml
concurrent = 4
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "myAwesomeRunner"
  token = "thisisNOTtheREGISTRATIONtoken"
  url = "https://gitlab.com"
  executor = "custom"
  output_limit = 131072
  builds_dir = "/home/gitlab-runner/builds"
  cache_dir = "/home/gitlab-runner/cache"
  [runners.custom_build_dir]
  [runners.cache]
    [runners.cache.s3]
    [runners.cache.gcs]
  [runners.custom]
    prepare_exec = "/opt/qubes-g2g-continuous-integration/runner/kvm/prepare.sh"
    run_exec = "/opt/qubes-g2g-continuous-integration/runner/kvm/run.sh"
    cleanup_exec = "/opt/qubes-g2g-continuous-integration/runner/kvm/cleanup.sh"
```

Ensure that `default` network is started and marked as autostart:
```bash
$ sudo virsh net-start default
$ sudo virsh net-autostart default
```

# bridge

If a system bridge needs to be used by a user:

```shell
echo "allow all" | sudo tee /etc/qemu/${USER}.conf
echo "include /etc/qemu/${USER}.conf" | sudo tee --append /etc/qemu/bridge.conf
sudo chown root:${USER} /etc/qemu/${USER}.conf
sudo chmod 640 /etc/qemu/${USER}.conf
sudo chown root:root /etc/qemu/bridge.conf
sudo chmod 0640 /etc/qemu/bridge.conf
sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
```

Simple solution:

```shell
echo "allow virbr0" > /etc/qemu/bridge.conf
chown root:kvm /etc/qemu/bridge.conf
chmod 0660 /etc/qemu/bridge.conf
chmod u+s /usr/lib/qemu/qemu-bridge-helper
```
