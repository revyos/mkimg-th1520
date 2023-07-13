#!/bin/bash
set -e

BOARD=
IMAGE_SIZE=4G
IMAGE_FILE=""
CHROOT_TARGET=rootfs

LOOP_DEVICE=""
EFI_MOUNTPOINT=""
BOOT_MOUNTPOINT=""
ROOT_MOUNTPOINT=""

BASE_TOOLS="binutils file tree sudo bash-completion openssh-server network-manager dnsmasq-base libpam-systemd ppp wireless-regdb wpasupplicant libengine-pkcs11-openssl iptables systemd-timesyncd vim usbutils libgles2 parted exfatprogs systemd-sysv mesa-vulkan-drivers"
XFCE_DESKTOP="xorg xfce4 desktop-base lightdm xfce4-terminal tango-icon-theme xfce4-notifyd xfce4-power-manager network-manager-gnome xfce4-goodies pulseaudio alsa-utils dbus-user-session rtkit pavucontrol thunar-volman eject gvfs gvfs-backends udisks2 dosfstools e2fsprogs libblockdev-crypto2 ntfs-3g polkitd blueman"
GNOME_DESKTOP="gnome-core avahi-daemon desktop-base file-roller gnome-tweaks gstreamer1.0-libav gstreamer1.0-plugins-ugly libgsf-bin libproxy1-plugin-networkmanager network-manager-gnome"
KDE_DESKTOP="kde-plasma-desktop"
BENCHMARK_TOOLS="glmark2-es2 mesa-utils vulkan-tools iperf3 stress-ng"
#FONTS="fonts-crosextra-caladea fonts-crosextra-carlito fonts-dejavu fonts-liberation fonts-liberation2 fonts-linuxlibertine fonts-noto-core fonts-noto-cjk fonts-noto-extra fonts-noto-mono fonts-noto-ui-core fonts-sil-gentium-basic"
FONTS="fonts-noto-core fonts-noto-cjk fonts-noto-mono fonts-noto-ui-core"
INCLUDE_APPS="chromium libqt5gui5-gles vlc gimp gimp-data-extras gimp-plugin-registry gimp-gmic"
EXTRA_TOOLS="i2c-tools net-tools ethtool"
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

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

make_imagefile()
{
    IMAGE_FILE="rootfs-$TIMESTAMP.ext4"
    truncate -s "$IMAGE_SIZE" "$IMAGE_FILE"

    mkfs.ext4 -F "$IMAGE_FILE"
}

pre_mkrootfs()
{
    mkdir "$CHROOT_TARGET"
    mount "$IMAGE_FILE" "$CHROOT_TARGET"
}

make_rootfs()
{
    mmdebstrap --architectures=riscv64 \
    --include="ca-certificates debian-ports-archive-keyring revyos-keyring thead-gles-addons locales dosfstools \
        $BASE_TOOLS $XFCE_DESKTOP $BENCHMARK_TOOLS $FONTS $INCLUDE_APPS $EXTRA_TOOLS $LIBREOFFICE" \
    sid "$CHROOT_TARGET" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-base/ sid main contrib non-free non-free-firmware" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-addons/ revyos-addons main" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-gles-21/ revyos-gles-21 main"
}

after_mkrootfs()
{
    # Set up fstab
    chroot "$CHROOT_TARGET" sh -c "echo '/dev/mmcblk0p3 /   auto    defaults    1 1' >> /etc/fstab"
    chroot "$CHROOT_TARGET" sh -c "echo '/dev/mmcblk0p2 /boot   auto    defaults    0 0' >> /etc/fstab"

    # apt update
    chroot "$CHROOT_TARGET" sh -c "apt update"
    
    # Add user
    chroot "$CHROOT_TARGET" sh -c "useradd -m -s /bin/bash -G adm,sudo debian"
    chroot "$CHROOT_TARGET" sh -c "echo 'debian:debian' | chpasswd"

    # Change hostname
    chroot "$CHROOT_TARGET" sh -c "echo lpi4a > /etc/hostname"
    chroot "$CHROOT_TARGET" sh -c "echo 127.0.1.1 lpi4a >> /etc/hosts"

    # Add timestamp file in /etc
    echo "$TIMESTAMP" > rootfs/etc/revyos-release

    # remove openssh keys
    rm -v rootfs/etc/ssh/ssh_host_*

    # copy addons to rootfs
    cp -rp addons/lib/firmware rootfs/lib/
    cp -rp addons/lib/modules rootfs/lib/
    cp -rp addons/sbin/perf-thead rootfs/sbin/

    # Add Bluetooth firmware and service
    cp -rp addons/lpi4a-bt/rootfs/usr/local/bin/rtk_hciattach rootfs/usr/local/bin/
    cp -rp addons/lpi4a-bt/rootfs/lib/firmware/rtlbt/rtl8723d_config rootfs/lib/firmware/rtlbt/
    cp -rp addons/lpi4a-bt/rootfs/lib/firmware/rtlbt/rtl8723d_fw rootfs/lib/firmware/rtlbt/
    cp -rp addons/etc/systemd/system/rtk-hciattach.service rootfs/etc/systemd/system/

    # Add firstboot service
    cp -rp addons/etc/systemd/system/firstboot.service rootfs/etc/systemd/system/
    cp -rp addons/opt/firstboot.sh rootfs/opt/

    # Install system services
    chroot "$CHROOT_TARGET" sh -c "systemctl enable pvrsrvkm"
    chroot "$CHROOT_TARGET" sh -c "systemctl enable firstboot"
    chroot "$CHROOT_TARGET" sh -c "systemctl enable rtk-hciattach"

    # Use iptables-legacy for docker
    chroot "$CHROOT_TARGET" sh -c "update-alternatives --set iptables /usr/sbin/iptables-legacy"
    chroot "$CHROOT_TARGET" sh -c "update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy"

    # Chromium add "--no-sandbox --use-gl=egl" flags
    # replace "Exec=/usr/bin/chromium %U" to "Exec=/usr/bin/chromium --no-sandbox --use-gl=egl %U"
    sed -i "s/Exec=\/usr\/bin\/chromium/Exec=\/usr\/bin\/chromium --no-sandbox --use-gl=egl/gi" rootfs/usr/share/applications/chromium.desktop

    # Temp add HDMI audio output on Volume control
    echo "load-module module-alsa-sink device=hw:0,2" >> rootfs/etc/pulse/default.pa

    # refresh so libs
    chroot "$CHROOT_TARGET" sh -c "rm -v /etc/ld.so.cache"
    chroot "$CHROOT_TARGET" sh -c "ldconfig"
}

unmount_image()
{
	echo "Finished and cleaning..."
	if mount | grep "$CHROOT_TARGET" > /dev/null; then
		umount -l "$CHROOT_TARGET"
	fi
	if [ "$(ls -A $CHROOT_TARGET)" ]; then
		echo "folder not empty! umount may fail!"
		exit 2
	else
		echo "Deleting chroot temp folder..."
		if [ -d "$CHROOT_TARGET" ]; then
			rmdir -v "$CHROOT_TARGET"
		fi
		echo "Done."
	fi
}

cleanup_env()
{
    echo "Cleanup temp files..."
    # remove temp file here
    echo "Done."
}

main()
{
# 	install_depends
	make_imagefile
	pre_mkrootfs
	make_rootfs
# 	make_kernel
# 	make_bootable
	after_mkrootfs
	exit
}

# Check root privileges:
if (( $EUID != 0 )); then
    echo "Please run as root"
    exit 1
fi

trap return 2 INT
trap clean_on_exit EXIT

clean_on_exit()
{
	if [ $? -eq 0 ]; then
		unmount_image
		cleanup_env
		echo "exit."
	else
		unmount_image
		cleanup_env
		if [ -f $IMAGE_FILE ]; then
			echo "delete image $IMAGE_FILE ..."
			rm -v "$IMAGE_FILE"
		fi
		echo "interrupted exit."
	fi
}

main