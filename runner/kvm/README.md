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
Generate the VM template used for runner jobs using the `generate-vm.sh` wrapper.
It must be run as root and handles all prerequisites automatically.

```shell
cd /opt/qubes-g2g-continuous-integration/runner/kvm

# Fedora (default version: 42)
sudo ./generate-vm.sh fedora
sudo ./generate-vm.sh fedora 41

# Debian (default version: 13 / trixie)
sudo ./generate-vm.sh debian
sudo ./generate-vm.sh debian 12

# Qubes OS standard flavor (default version: 4.3) - auto-downloads latest passing image from OpenQA
sudo ./generate-vm.sh qubesos
sudo ./generate-vm.sh qubesos 4.2

# Qubes OS debian flavor (default version: 4.3) - auto-downloads latest passing image from OpenQA
sudo ./generate-vm.sh qubesos-debian
sudo ./generate-vm.sh qubesos-debian 4.2

# Use an existing local image instead of downloading
sudo ./generate-vm.sh qubesos 4.3 /var/lib/libvirt/images/my-qubes.qcow2
sudo ./generate-vm.sh qubesos-debian 4.3 /var/lib/libvirt/images/my-qubes-debian.qcow2

# Enable verbose libguestfs output
sudo ./generate-vm.sh --debug fedora
```

Output images and their versionless symlinks in `/var/lib/libvirt/images/`:

| Type | Versioned image | Symlink |
|------|----------------|---------|
| `fedora` | `gitlab-runner-fedora-42.qcow2` | `gitlab-runner-fedora.qcow2` |
| `debian` | `gitlab-runner-debian-13.qcow2` | `gitlab-runner-debian.qcow2` |
| `qubesos` | `qubes_4.3_64bit_stable.qcow2` | `qubes_64bit_stable.qcow2` |
| `qubesos-debian` | `qubes_debian_4.3_64bit_stable.qcow2` | `qubes_debian_64bit_stable.qcow2` |

The wrapper:
- Makes `/boot/vmlinuz-*` readable for `supermin` (required on Debian/Ubuntu)
- Ensures the `libvirt` group has write access to `/var/lib/libvirt/images/`
- Resolves `gitlab-runner`'s SSH public key and injects it into the VM
- Runs `virt-builder`/`virt-customize` as `gitlab-runner` (not root) to avoid a `passt` privilege issue
- For `qubesos` and `qubesos-debian`, downloads the latest passing job from OpenQA (`install_unencrypted_full_upload` / `install_unencrypted_debian_upload`); supports resume and verifies size on completion
- Fixes ownership of the qubesos image to `gitlab-runner` before customization so `virt-customize` can write to it
- Sets the final image ownership to `libvirt-qemu:kvm` with mode `660`
- Creates a versionless symlink pointing to the versioned image

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
