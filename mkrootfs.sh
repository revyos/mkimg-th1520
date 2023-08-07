#!/bin/bash
set -e

BOARD=
IMAGE_SIZE=4500M
IMAGE_FILE=""
BOOT_SIZE=500M
BOOT_IMG=""
ROOT_SIZE=4G
ROOT_IMG=""
CHROOT_TARGET=rootfs

LOOP_DEVICE=""
EFI_MOUNTPOINT=""
BOOT_MOUNTPOINT=""
ROOT_MOUNTPOINT=""

KERNEL="linux-headers-5.10.113-lpi4a linux-image-5.10.113-lpi4a linux-perf-thead"
BASE_TOOLS="binutils file tree sudo bash-completion u-boot-menu initramfs-tools openssh-server network-manager dnsmasq-base libpam-systemd ppp wireless-regdb wpasupplicant libengine-pkcs11-openssl iptables systemd-timesyncd vim usbutils libgles2 parted exfatprogs systemd-sysv mesa-vulkan-drivers"
XFCE_DESKTOP="xorg xfce4 desktop-base lightdm xfce4-terminal tango-icon-theme xfce4-notifyd xfce4-power-manager network-manager-gnome xfce4-goodies pulseaudio alsa-utils dbus-user-session rtkit pavucontrol thunar-volman eject gvfs gvfs-backends udisks2 dosfstools e2fsprogs libblockdev-crypto2 ntfs-3g polkitd blueman xarchiver"
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
BRANDING="dynamic-motd"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

make_imagefile()
{
    BOOT_IMG="boot-$TIMESTAMP.ext4"
    truncate -s "$BOOT_SIZE" "$BOOT_IMG"
    ROOT_IMG="root-$TIMESTAMP.ext4"
    truncate -s "$ROOT_SIZE" "$ROOT_IMG"

    # Format partitions
    mkfs.ext4 -F "$BOOT_IMG"
    mkfs.ext4 -F "$ROOT_IMG"
}

pre_mkrootfs()
{
    # Mount loop device
    mkdir "$CHROOT_TARGET"
    mount "$ROOT_IMG" "$CHROOT_TARGET"
}

make_rootfs()
{
    mmdebstrap --architectures=riscv64 \
    --include="ca-certificates debian-ports-archive-keyring revyos-keyring thead-gles-addons th1520-boot-firmware locales dosfstools \
        $BASE_TOOLS $XFCE_DESKTOP $BENCHMARK_TOOLS $FONTS $INCLUDE_APPS $EXTRA_TOOLS $LIBREOFFICE" \
    sid "$CHROOT_TARGET" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-base/ sid main contrib non-free non-free-firmware" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-kernels/ revyos-kernels main" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-addons/ revyos-addons main" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-gles-21/ revyos-gles-21 main"

    # Mount chroot path
    mount "$BOOT_IMG" "$CHROOT_TARGET"/boot
    mount -t proc /proc "$CHROOT_TARGET"/proc
    mount -B /sys "$CHROOT_TARGET"/sys
    mount -B /run "$CHROOT_TARGET"/run
    mount -B /dev "$CHROOT_TARGET"/dev
    mount -B /dev/pts "$CHROOT_TARGET"/dev/pts

    # apt update
    chroot "$CHROOT_TARGET" sh -c "apt update"
}

make_bootable()
{
    # Install kernel
    chroot "$CHROOT_TARGET" sh -c "apt install $KERNEL"

    # Add update-u-boot config
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_PROMPT=\"2\"' >> /etc/default/u-boot"
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_MENU_LABEL=\"RevyOS GNU/Linux\"' >> /etc/default/u-boot"
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_PARAMETERS=\"console=ttyS0,115200 rootwait rw earlycon clk_ignore_unused loglevel=7 eth=$ethaddr rootrwoptions=rw,noatime rootrwreset=yes\"' >> /etc/default/u-boot"
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_FDT=\"light-lpi4a.dtb\"' >> /etc/default/u-boot"
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_ROOT=\"root=/dev/mmcblk0p3\"' >> /etc/default/u-boot"

    # Copy device tree to /boot

    cp -rp "$CHROOT_TARGET"/usr/lib/linux-image-5.10.113-lpi4a/thead/light-lpi4a.dtb "$CHROOT_TARGET"/boot/

    # Update extlinux config
    chroot "$CHROOT_TARGET" sh -c "u-boot-update"

    # Copy firmware to /boot
    cp -v addons/boot/* "$CHROOT_TARGET"/boot/
}

after_mkrootfs()
{
    # Set up fstab
    chroot "$CHROOT_TARGET" sh -c "echo '/dev/mmcblk0p3 /   auto    defaults    1 1' >> /etc/fstab"
    chroot "$CHROOT_TARGET" sh -c "echo '/dev/mmcblk0p2 /boot   auto    defaults    0 0' >> /etc/fstab"

    # apt update
    # chroot "$CHROOT_TARGET" sh -c "apt update"
    
    # Add user
    chroot "$CHROOT_TARGET" sh -c "useradd -m -s /bin/bash -G adm,sudo debian"
    chroot "$CHROOT_TARGET" sh -c "echo 'debian:debian' | chpasswd"

    chroot "$CHROOT_TARGET" sh -c "useradd -m -s /bin/bash -G adm,sudo sipeed"
    chroot "$CHROOT_TARGET" sh -c "echo 'sipeed:licheepi' | chpasswd"

    # Change hostname
    chroot "$CHROOT_TARGET" sh -c "echo lpi4a > /etc/hostname"
    chroot "$CHROOT_TARGET" sh -c "echo 127.0.1.1 lpi4a >> /etc/hosts"

    # Add timestamp file in /etc
    echo "$TIMESTAMP" > rootfs/etc/revyos-release

    # remove openssh keys
    rm -v rootfs/etc/ssh/ssh_host_*

    # copy addons to rootfs
    cp -rp addons/lib/firmware rootfs/lib/

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
    sed -i "s/Exec=\/usr\/bin\/chromium/Exec=\/usr\/bin\/chromium --no-sandbox --use-gl=egl/gi" "$CHROOT_TARGET"/usr/share/applications/chromium.desktop

    # Temp add HDMI audio output on Volume control
    echo "load-module module-alsa-sink device=hw:0,2" >> "$CHROOT_TARGET"/etc/pulse/default.pa

    # Change xfce4-panel default web-browser icon to chromium
    sed -i 's/xfce4-web-browser.desktop/chromium.desktop/g' "$CHROOT_TARGET"/etc/xdg/xfce4/panel/default.xml 

    # Fix cann't connect bluetooth headphone
    sed -i 's/load-module module-bluetooth-policy/load-module module-bluetooth-policy auto_switch=false/g' "$CHROOT_TARGET"/etc/pulse/default.pa

    # Install other packages
    chroot "$CHROOT_TARGET" sh -c "apt install -y parole th1520-vpu"

    # Setup branding related
    chroot "$CHROOT_TARGET" sh -c "apt install -y $BRANDING "
    rm -vr "$CHROOT_TARGET"/etc/update-motd.d
    cp -rp addons/etc/update-motd.d "$CHROOT_TARGET"/etc/
    # Wallpaper
    cp -rp addons/usr/share/images/ruyisdk "$CHROOT_TARGET"/usr/share/images/
    chroot "$CHROOT_TARGET" sh -c "rm -v /usr/share/images/desktop-base/desktop-background"
    chroot "$CHROOT_TARGET" sh -c "rm -v /usr/share/images/desktop-base/login-background.svg"
    chroot "$CHROOT_TARGET" sh -c "ln -s /usr/share/images/ruyisdk/ruyi-1-1920x1080.png /usr/share/images/desktop-base/desktop-background"
    chroot "$CHROOT_TARGET" sh -c "ln -s /usr/share/images/ruyisdk/ruyi-2-1920x1080.png /usr/share/images/desktop-base/login-background.svg"

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
	make_bootable
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
		if [ -f $BOOT_IMG ]; then
			echo "delete image $BOOT_IMG ..."
			rm -v "$BOOT_IMG"
		fi
		if [ -f $ROOT_IMG ]; then
			echo "delete image $ROOT_IMG ..."
			rm -v "$ROOT_IMG"
		fi
		echo "interrupted exit."
	fi
}

main