qubes-g2g-continuous-integration
===

Repository for creating Gitlab CI/CD pipelines from Github

Inspired from [signature-checker](https://github.com/marmarek/signature-checker) made by
Marek Marczykowski-Górecki <marmarek@invisiblethingslab.com>.

Example CONFIG:
```
[DEFAULT]
home = /home/user/qubes-g2g-continuous-integration
owner_whitelist = QubesOS
#repo_whitelist = qubes-linux-kernel qubes-core-vchan-xen qubes-core-qubesdb qubes-core-qrexec qubes-core-agent-linux qubes-linux-utils qubes-gui-common qubes-gui-agent-linux qubes-app-linux-split-gpg qubes-app-linux-usb-proxy qubes-app-linux-input-proxy qubes-app-linux-img-converter qubes-app-linux-pdf-converter qubes-app-thunderbird
repo_whitelist = qubes-vmm-xen qubes-core-libvirt qubes-core-vchan-xen qubes-core-qubesdb qubes-core-qrexec qubes-linux-utils qubes-python-qasync qubes-python-panflute qubes-core-admin qubes-core-admin-client qubes-core-admin-addon-whonix qubes-core-admin-linux qubes-core-agent-linux qubes-intel-microcode qubes-linux-firmware qubes-linux-kernel qubes-artwork qubes-grub2 qubes-grub2-theme qubes-gui-common qubes-gui-daemon qubes-gui-agent-linux qubes-seabios qubes-vmm-xen-stubdom-legacy qubes-vmm-xen-stubdom-linux qubes-app-linux-split-gpg qubes-app-thunderbird qubes-app-linux-pdf-converter qubes-app-linux-img-converter qubes-app-linux-input-proxy qubes-app-linux-usb-proxy qubes-app-linux-snapd-helper qubes-app-shutdown-idle qubes-app-yubikey qubes-app-u2f qubes-infrastructure qubes-meta-packages qubes-manager qubes-desktop-linux-common qubes-desktop-linux-kde qubes-desktop-linux-xfce4 qubes-desktop-linux-xfce4-xfwm4 qubes-desktop-linux-i3 qubes-desktop-linux-i3-settings-qubes qubes-desktop-linux-awesome qubes-desktop-linux-manager qubes-grubby-dummy qubes-linux-pvgrub2 qubes-linux-gbulb qubes-linux-scrypt qubes-librepo qubes-libcomps qubes-libdnf qubes-dnf qubes-installer-qubes-os qubes-qubes-release qubes-pykickstart qubes-blivet qubes-lorax qubes-lorax-templates qubes-anaconda qubes-anaconda-addon qubes-tpm-extra qubes-trousers-changer qubes-antievilmaid qubes-builder qubes-builder-rpm qubes-builder-debian qubes-builder-archlinux qubes-builder-gentoo qubes-mgmt-salt qubes-mgmt-salt-base qubes-mgmt-salt-base-topd qubes-mgmt-salt-base-config qubes-mgmt-salt-dom0-qvm qubes-mgmt-salt-dom0-virtual-machines qubes-mgmt-salt-dom0-update qubes-doc qubes-posts qubesos.github.io
user_whitelist = fepitre marmarek woju
#github_app_id = ...
#pem_file_path = ...
#github_installation_id = ...
#gitlab_api_token = ...
#github_api_token = ...
```

RPC installation:
```
sudo ln -sf "$PWD/qubes-rpc/gitlabci.GithubCommand" /rw/usrlocal/etc/qubes-rpc/
sudo ln -sf "$PWD/qubes-rpc/gitlabci.GithubPullRequest" /rw/usrlocal/etc/qubes-rpc/
sudo ln -sf "$PWD/qubes-rpc/gitlabci.GitlabPipelineStatus" /rw/usrlocal/etc/qubes-rpc/
```