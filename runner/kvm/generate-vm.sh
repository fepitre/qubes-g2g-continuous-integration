#!/bin/bash
# See README.md for usage and documentation.
# Must be run as root (e.g. via sudo).
# Pass --debug as first argument to enable verbose libguestfs output.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_IMAGES_PATH="/var/lib/libvirt/images"
OPENQA_BASE_URL="https://openqa.qubes-os.org"
OPENQA_API="$OPENQA_BASE_URL/api/v1"
LIBGUESTFS_EXTRA_VARS=""

#
# Argument parsing
#

# Optional --debug flag (must be first argument)
if [ "${1:-}" = "--debug" ]; then
    LIBGUESTFS_EXTRA_VARS="export LIBGUESTFS_DEBUG=1 LIBGUESTFS_TRACE=1"
    shift
else
    LIBGUESTFS_EXTRA_VARS=""
fi

VM_TYPE="${1:-}"
if [ -z "$VM_TYPE" ]; then
    echo "Usage: $0 [--debug] <fedora|debian|qubesos|qubesos-debian> [version] [/var/lib/libvirt/images/image.qcow2]"
    exit 1
fi

#
# Prerequisite checks (require root)
#

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

# Ensure /boot/vmlinuz-* is readable for supermin (libguestfs on Debian/Ubuntu)
chmod 644 /boot/vmlinuz-* 2>/dev/null || true

# Ensure gitlab-runner can write to the libvirt images directory
chgrp libvirt "$VM_IMAGES_PATH"
chmod g+w "$VM_IMAGES_PATH"

# Resolve gitlab-runner's SSH public key
SSH_PUB_KEY=""
for candidate in /home/gitlab-runner/.ssh/id_ed25519.pub \
                 /var/lib/gitlab-runner/.ssh/id_ed25519.pub \
                 "$SCRIPT_DIR/id_ed25519.pub"; do
    if [ -e "$candidate" ]; then
        SSH_PUB_KEY="$candidate"
        break
    fi
done
if [ -z "$SSH_PUB_KEY" ]; then
    echo "Cannot find gitlab-runner's SSH public key."
    exit 1
fi
echo "Using SSH public key: $SSH_PUB_KEY"

#
# OpenQA image download helper
#

# Download the latest passing image for a given OpenQA test name.
# Supports resuming interrupted downloads and verifies size on completion.
# Usage: download_openqa_image <test_name> <version> <output_path>
download_openqa_image() {
    local test_name="$1"
    local version="$2"
    local output_path="$3"

    echo "Querying OpenQA for latest passing '$test_name' (version $version) job..."
    local job_id asset_name
    job_id=$(curl -fsSL "$OPENQA_API/jobs?distri=qubesos&version=${version}&latest=1&groupid=1&test=$test_name" \
        | python3 -c "
import sys, json
jobs = json.load(sys.stdin)['jobs']
passing = [j for j in jobs if j['result'] in ('passed', 'softfailed')]
if not passing:
    raise SystemExit('No passing job found for test: $test_name')
print(max(passing, key=lambda j: j['id'])['id'])
")

    echo "Found job: $job_id"
    asset_name=$(curl -fsSL "$OPENQA_API/jobs/$job_id" \
        | python3 -c "
import sys, json
assets = json.load(sys.stdin)['job']['assets']['hdd']
print(assets[0])
")

    local url="$OPENQA_BASE_URL/assets/hdd/$asset_name"

    # Get expected size from the OpenQA assets API
    local expected_size
    expected_size=$(curl -fsSL "$OPENQA_API/assets/hdd/$asset_name" \
        | python3 -c "import sys, json; print(json.load(sys.stdin)['size'])")

    # Check if existing file is already complete
    if [ -f "$output_path" ]; then
        local actual_size
        actual_size=$(stat -c '%s' "$output_path")
        if [ "$actual_size" -eq "$expected_size" ]; then
            echo "File already complete ($actual_size bytes), skipping download."
            return 0
        else
            echo "Partial file found ($actual_size / $expected_size bytes), resuming..."
        fi
    fi

    echo "Downloading $asset_name ($(( expected_size / 1024 / 1024 / 1024 )) GB)..."
    curl -fL --progress-bar -C - -o "$output_path" "$url"

    # Verify size after download
    local actual_size
    actual_size=$(stat -c '%s' "$output_path")
    if [ "$actual_size" -ne "$expected_size" ]; then
        echo "ERROR: Size mismatch after download (expected $expected_size, got $actual_size)."
        exit 1
    fi
    echo "Size verified ($actual_size bytes)."

    echo "Saved to $output_path"
}

#
# Generator functions (run as gitlab-runner)
#

generate_fedora() {
    local ssh_pub_key="$1"
    local version="$2"
    local output="$VM_IMAGES_PATH/gitlab-runner-fedora-${version}.qcow2"
    local packages
    packages="$(tr '\n' ',' < "$SCRIPT_DIR/packages_fedora.list")"
    packages="${packages%,}"

    cd "$SCRIPT_DIR"
    virt-builder "fedora-${version}" \
        --smp 4 \
        --memsize 4096 \
        --size 80G \
        --output "$output" \
        --format qcow2 \
        --hostname "gitlab-runner-fedora-${version}" \
        --network \
        --run-command "rm -rf /etc/yum.repos.d/*modular*.repo /etc/yum.repos.d/fedora-cisco-openh264.repo; " \
        --copy-in "gitlab_runner.repo:/etc/yum.repos.d/" \
        --copy-in "gpgkey:/etc/pki/rpm-gpg/" \
        --copy-in "runner-gitlab-runner-49F16C5CC3A0F81F.pub.gpg:/etc/pki/rpm-gpg/" \
        --copy-in "eth0.nmconnection:/etc/NetworkManager/system-connections/" \
        --run-command "chmod 600 /etc/NetworkManager/system-connections/eth0.nmconnection" \
        --install "$packages" \
        --run-command "dnf update -y kernel kernel-devel" \
        --run-command "git lfs install --skip-repo" \
        --ssh-inject "gitlab-runner:file:$ssh_pub_key" \
        --run-command "usermod -u 11000 gitlab-runner" \
        --run-command "groupmod -g 11000 gitlab-runner" \
        --run-command "rm -f /root/.ssh/known_hosts" \
        --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
        --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
        --run-command "grub2-mkconfig -o /boot/grub2/grub.cfg" \
        --run-command "sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config" \
        --run-command "usermod -aG docker gitlab-runner" \
        --run-command "systemctl enable docker" \
        --run-command "cd /tmp && git clone https://github.com/qubesos/qubes-infrastructure-mirrors && cd qubes-infrastructure-mirrors && python3 setup.py build install" \
        --run-command "sed -i -e 's/^##\(activate = 1\|.*default_sect\|.*legacy_sect\)/\1/' /etc/pki/tls/openssl.cnf" \
        --root-password password:root \
        --update
}

generate_debian() {
    local ssh_pub_key="$1"
    local version="$2"
    local output="$VM_IMAGES_PATH/gitlab-runner-debian-${version}.qcow2"

    virt-builder "debian-${version}" \
        --size 80G \
        --output "$output" \
        --format qcow2 \
        --hostname "gitlab-runner-debian-${version}" \
        --network \
        --run-command "ln -sf /dev/sda /dev/vda" \
        --run-command "echo 'grub-pc grub-pc/install_devices string /dev/sda' | debconf-set-selections" \
        --run-command "echo 'grub-pc grub-pc/install_devices_empty boolean false' | debconf-set-selections" \
        --update \
        --run-command "mkdir -p /etc/apt/keyrings" \
        --run-command "curl -fsSL https://packages.gitlab.com/runner/gitlab-runner/gpgkey | gpg --dearmor -o /etc/apt/keyrings/gitlab-runner.gpg" \
        --run-command "echo 'deb [signed-by=/etc/apt/keyrings/gitlab-runner.gpg] https://packages.gitlab.com/runner/gitlab-runner/debian/ trixie main' > /etc/apt/sources.list.d/gitlab-runner.list" \
        --run-command "curl -fsSL https://packagecloud.io/github/git-lfs/gpgkey | gpg --dearmor -o /etc/apt/keyrings/git-lfs.gpg" \
        --run-command "echo 'deb [signed-by=/etc/apt/keyrings/git-lfs.gpg] https://packagecloud.io/github/git-lfs/debian/ trixie main' > /etc/apt/sources.list.d/git-lfs.list" \
        --run-command "apt-get update" \
        --run-command "DEBIAN_FRONTEND=noninteractive apt-get install -y curl sudo coreutils dpkg-dev debootstrap git python3-sh wget rpm devscripts rsync python3-packaging createrepo-c gpg python3-yaml docker.io python3-docker reprepro python3-pathspec mktorrent openssl tree python3-setuptools python3-lxml gitlab-runner git-lfs openssh-server" \
        --run-command "git lfs install --skip-repo" \
        --run-command 'useradd -m -u 11000 -p "" gitlab-runner -s /bin/bash' \
        --ssh-inject "gitlab-runner:file:$ssh_pub_key" \
        --run-command "groupmod -g 11000 gitlab-runner" \
        --run-command "rm -f /root/.ssh/known_hosts" \
        --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
        --run-command "sed -E 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0\"/' -i /etc/default/grub" \
        --run-command "grub-install /dev/sda" \
        --run-command "grub-mkconfig -o /boot/grub/grub.cfg" \
        --run-command "echo 'auto eth0' >> /etc/network/interfaces" \
        --run-command "echo 'allow-hotplug eth0' >> /etc/network/interfaces" \
        --run-command "echo 'iface eth0 inet dhcp' >> /etc/network/interfaces" \
        --root-password password:root
}

generate_qubesos() {
    local qubes_image="$1"
    local ssh_pub_key="$2"

    virt-customize -a "$qubes_image" \
        --run-command "sed -i 's|self.netdevs.extend(self.find_devices_of_class(vm, \"02\"))|self.netdevs.extend(sorted(self.find_devices_of_class(vm, \"02\"))[:1])|' /root/extra-files/qubesteststub/__init__.py" \
        --run-command 'cd /root/extra-files/ && python3 setup.py build && python3 setup.py install' \
        --copy-in "$SCRIPT_DIR/gitlab_runner.repo:/etc/yum.repos.d/" \
        --copy-in "$SCRIPT_DIR/gpgkey:/etc/pki/rpm-gpg/" \
        --copy-in "$SCRIPT_DIR/runner-gitlab-runner-49F16C5CC3A0F81F.pub.gpg:/etc/pki/rpm-gpg/" \
        --run-command "sed -i.bak -e '0,/id=\"00_05\.0\"/{ /id=\"00_05\.0\"/{N;N;d;} }' -e 's|id=\"00_03.0.*::p020000\"|id=\"00_01.0-00_00.0\"|' /var/lib/qubes/qubes.xml" \
        --run-command "dnf install --disablerepo=* --enablerepo=fedora --enablerepo=updates --enablerepo=runner_gitlab-runner --setopt=reposdir=/etc/yum.repos.d -y openssh-server dhcp-client git git-lfs gitlab-runner" \
        --run-command "usermod -u 11000 gitlab-runner" \
        --run-command "usermod -aG qubes gitlab-runner" \
        --run-command "groupmod -g 11000 gitlab-runner" \
        --ssh-inject "gitlab-runner:file:$ssh_pub_key" \
        --run-command "echo 'gitlab-runner ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers" \
        --mkdir /var/lib/qubes-service/ \
        --touch /var/lib/qubes-service/sshd \
        --copy-in "$SCRIPT_DIR/setup-dom0-net.sh:/usr/local/bin/" \
        --copy-in "$SCRIPT_DIR/setup-direct-dom0-net.sh:/usr/local/bin/" \
        --chmod 0775:/usr/local/bin/setup-dom0-net.sh \
        --chmod 0775:/usr/local/bin/setup-direct-dom0-net.sh \
        --mkdir /etc/systemd/system/sshd.service.d \
        --copy-in "$SCRIPT_DIR/setup-direct-net.service:/etc/systemd/system/" \
        --copy-in "$SCRIPT_DIR/custom.conf:/etc/systemd/system/sshd.service.d/" \
        --run-command 'systemctl daemon-reload' \
        --run-command 'systemctl enable sshd' \
        --run-command 'rm -rf /etc/pki/rpm-gpg/gpgkey /etc/pki/rpm-gpg/runner-gitlab-runner-49F16C5CC3A0F81F.pub.gpg /etc/yum.repos.d/gitlab_runner.repo'
}

#
# Main
#

case "$VM_TYPE" in
    fedora)
        VERSION="${2:-42}"
        OUTPUT_IMAGE="$VM_IMAGES_PATH/gitlab-runner-fedora-${VERSION}.qcow2"
        SYMLINK="$VM_IMAGES_PATH/gitlab-runner-fedora.qcow2"
        sudo -u gitlab-runner bash -c "
            $LIBGUESTFS_EXTRA_VARS
            SCRIPT_DIR='$SCRIPT_DIR'
            VM_IMAGES_PATH='$VM_IMAGES_PATH'
            $(declare -f generate_fedora)
            generate_fedora '$SSH_PUB_KEY' '$VERSION'
        "
        ;;
    debian)
        VERSION="${2:-13}"
        OUTPUT_IMAGE="$VM_IMAGES_PATH/gitlab-runner-debian-${VERSION}.qcow2"
        SYMLINK="$VM_IMAGES_PATH/gitlab-runner-debian.qcow2"
        sudo -u gitlab-runner bash -c "
            $LIBGUESTFS_EXTRA_VARS
            SCRIPT_DIR='$SCRIPT_DIR'
            VM_IMAGES_PATH='$VM_IMAGES_PATH'
            $(declare -f generate_debian)
            generate_debian '$SSH_PUB_KEY' '$VERSION'
        "
        ;;
    qubesos)
        VERSION="${2:-4.3}"
        OUTPUT_IMAGE="${3:-}"
        SYMLINK="$VM_IMAGES_PATH/qubes_64bit_stable.qcow2"
        if [ -z "$OUTPUT_IMAGE" ]; then
            OUTPUT_IMAGE="$VM_IMAGES_PATH/qubes_${VERSION}_64bit_stable.qcow2"
            download_openqa_image "install_unencrypted_full_upload" "$VERSION" "$OUTPUT_IMAGE"
        fi
        chown gitlab-runner:gitlab-runner "$OUTPUT_IMAGE"
        sudo -u gitlab-runner bash -c "
            $LIBGUESTFS_EXTRA_VARS
            SCRIPT_DIR='$SCRIPT_DIR'
            VM_IMAGES_PATH='$VM_IMAGES_PATH'
            $(declare -f generate_qubesos)
            generate_qubesos '$OUTPUT_IMAGE' '$SSH_PUB_KEY'
        "
        ;;
    qubesos-debian)
        VERSION="${2:-4.3}"
        OUTPUT_IMAGE="${3:-}"
        SYMLINK="$VM_IMAGES_PATH/qubes_debian_64bit_stable.qcow2"
        if [ -z "$OUTPUT_IMAGE" ]; then
            OUTPUT_IMAGE="$VM_IMAGES_PATH/qubes_debian_${VERSION}_64bit_stable.qcow2"
            download_openqa_image "install_unencrypted_debian_upload" "$VERSION" "$OUTPUT_IMAGE"
        fi
        chown gitlab-runner:gitlab-runner "$OUTPUT_IMAGE"
        sudo -u gitlab-runner bash -c "
            $LIBGUESTFS_EXTRA_VARS
            SCRIPT_DIR='$SCRIPT_DIR'
            VM_IMAGES_PATH='$VM_IMAGES_PATH'
            $(declare -f generate_qubesos)
            generate_qubesos '$OUTPUT_IMAGE' '$SSH_PUB_KEY'
        "
        ;;
    *)
        echo "Unknown VM type: $VM_TYPE. Use 'fedora', 'debian', 'qubesos', or 'qubesos-debian'."
        exit 1
        ;;
esac

# Fix ownership and permissions on the output image
chown libvirt-qemu:kvm "$OUTPUT_IMAGE"
chmod 660 "$OUTPUT_IMAGE"

# Create versionless symlink if applicable (e.g. gitlab-runner-fedora.qcow2 -> gitlab-runner-fedora-42.qcow2)
if [ -n "${SYMLINK:-}" ]; then
    ln -sf "$(basename "$OUTPUT_IMAGE")" "$SYMLINK"
    echo "Symlink: $SYMLINK -> $(basename "$OUTPUT_IMAGE")"
fi

echo "Done: $OUTPUT_IMAGE"
