#!/bin/bash

source $(pwd)/scripts/boards_list.sh

# == kernel variables ==
FRIMWARE="th1520-mainline-opensbi th1520-boot-firmware firmware-realtek aic8800-firmware"
VENDOR_66_KERNEL="linux-headers-6.6-th1520 linux-image-6.6-th1520"
BPO_MAINLINE_KERNEL="linux-headers-riscv64 linux-image-riscv64"
KERNEL_lpi4a="${VENDOR_66_KERNEL} ${FRIMWARE}"
KERNEL_ahead="${VENDOR_66_KERNEL} ${FRIMWARE}"
KERNEL_console="${VENDOR_66_KERNEL} ${FRIMWARE}"
KERNEL_laptop="${VENDOR_66_KERNEL} ${FRIMWARE}"
KERNEL_meles="${VENDOR_66_KERNEL} ${FRIMWARE}"
KERNEL_lpi4amain="${BPO_MAINLINE_KERNEL} ${FRIMWARE}"
KERNEL=$(eval echo '$'"KERNEL_${BOARD}")

PACKAGE_LIST=""
KEYRINGS="ca-certificates debian-ports-archive-keyring revyos-keyring"
GPU_DRIVER="th1520-img xserver-xorg-video-th1520"
BASE_TOOLS="locales locales-all binutils file tree sudo bash-completion u-boot-menu u-boot-fdtdir-dtb initramfs-tools openssh-server network-manager dnsmasq-base libpam-systemd ppp wireless-regdb wpasupplicant libengine-pkcs11-openssl iptables systemd-timesyncd vim usbutils dosfstools parted exfatprogs systemd-sysv pkexec arch-install-scripts bluez cloud-guest-utils cloud-init"
GRAPHIC_TOOLS="libgles2 mesa-vulkan-drivers glmark2-es2 mesa-utils vulkan-tools"
XFCE_DESKTOP="xorg xinput xfce4 desktop-base lightdm xfce4-terminal tango-icon-theme xfce4-notifyd xfce4-power-manager network-manager-gnome xfce4-goodies pulseaudio pulseaudio-module-bluetooth alsa-utils alsa-ucm-conf dbus-user-session rtkit pavucontrol thunar-volman eject gvfs gvfs-backends udisks2 e2fsprogs libblockdev-crypto2 ntfs-3g polkitd blueman xarchiver"
GNOME_DESKTOP="gnome-core avahi-daemon desktop-base file-roller gnome-tweaks gstreamer1.0-libav gstreamer1.0-plugins-ugly libgsf-bin libproxy1-plugin-networkmanager network-manager-gnome"
KDE_DESKTOP="kde-plasma-desktop"
BENCHMARK_TOOLS="iperf3 stress-ng"
#FONTS="fonts-crosextra-caladea fonts-crosextra-carlito fonts-dejavu fonts-liberation fonts-liberation2 fonts-linuxlibertine fonts-noto-core fonts-noto-cjk fonts-noto-extra fonts-noto-mono fonts-noto-ui-core fonts-sil-gentium-basic"
FONTS="fonts-noto-core fonts-noto-cjk fonts-noto-mono fonts-noto-ui-core"
INCLUDE_APPS="chromium libqt5gui5-gles vlc gimp gimp-data-extras gimp-plugin-registry gimp-gmic"
EXTRA_TOOLS="i2c-tools net-tools ethtool xdotool python3-ruyi"
LIBREOFFICE="libreoffice-base \
libreoffice-calc \
libreoffice-core \
libreoffice-draw \
libreoffice-impress \
libreoffice-math \
libreoffice-report-builder-bin \
libreoffice-writer \
libreoffice-nlpsolver \
libreoffice-report-builder \
libreoffice-script-provider-bsh \
libreoffice-script-provider-js \
libreoffice-script-provider-python \
libreoffice-sdbc-mysql \
libreoffice-sdbc-postgresql \
libreoffice-wiki-publisher \
"
DOCKER="docker.io apparmor ca-certificates cgroupfs-mount git needrestart xz-utils"
BRANDING="lsb-release figlet dynamic-motd"
