#!/bin/bash
set -e

BOARD=${BOARD:-lpi4a} # lpi4a, ahead
BOOT_SIZE=500M
BOOT_IMG=""
ROOT_SIZE=4G
ROOT_IMG=""
CHROOT_TARGET=rootfs

LOOP_DEVICE=""
EFI_MOUNTPOINT=""
BOOT_MOUNTPOINT=""
ROOT_MOUNTPOINT=""

# == kernel variables ==
KERNEL_lpi4a="linux-headers-5.10.113-lpi4a linux-image-5.10.113-lpi4a linux-perf-thead"
KERNEL_ahead="linux-headers-5.10.113-ahead linux-image-5.10.113-ahead linux-perf-thead"
KERNEL_console="linux-headers-5.10.113-lpi4a linux-image-5.10.113-lpi4a linux-perf-thead"
KERNEL_lpi4amain="linux-headers-6.7.1-lpi4a linux-image-6.7.1-lpi4a th1520-mainline-opensbi"
KERNEL=$(eval echo '$'"KERNEL_${BOARD}")

BASE_TOOLS="binutils file tree sudo bash-completion u-boot-menu initramfs-tools openssh-server network-manager dnsmasq-base libpam-systemd ppp wireless-regdb wpasupplicant libengine-pkcs11-openssl iptables systemd-timesyncd vim usbutils libgles2 parted exfatprogs systemd-sysv mesa-vulkan-drivers pkexec arch-install-scripts"
XFCE_DESKTOP="xorg xserver-xorg-video-thead xinput xfce4 desktop-base lightdm xfce4-terminal tango-icon-theme xfce4-notifyd xfce4-power-manager network-manager-gnome xfce4-goodies pulseaudio pulseaudio-module-bluetooth alsa-utils dbus-user-session rtkit pavucontrol thunar-volman eject gvfs gvfs-backends udisks2 dosfstools e2fsprogs libblockdev-crypto2 ntfs-3g polkitd blueman xarchiver"
GNOME_DESKTOP="gnome-core avahi-daemon desktop-base file-roller gnome-tweaks gstreamer1.0-libav gstreamer1.0-plugins-ugly libgsf-bin libproxy1-plugin-networkmanager network-manager-gnome"
KDE_DESKTOP="kde-plasma-desktop"
BENCHMARK_TOOLS="glmark2-es2 mesa-utils vulkan-tools iperf3 stress-ng"
#FONTS="fonts-crosextra-caladea fonts-crosextra-carlito fonts-dejavu fonts-liberation fonts-liberation2 fonts-linuxlibertine fonts-noto-core fonts-noto-cjk fonts-noto-extra fonts-noto-mono fonts-noto-ui-core fonts-sil-gentium-basic"
FONTS="fonts-noto-core fonts-noto-cjk fonts-noto-mono fonts-noto-ui-core"
INCLUDE_APPS="chromium libqt5gui5-gles vlc gimp gimp-data-extras gimp-plugin-registry gimp-gmic"
EXTRA_TOOLS="i2c-tools net-tools ethtool xdotool"
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
    if [ -f revyos-release ]; then
        echo "Found revyos-release, using timestamp in this file."
        . ./revyos-release
        TIMESTAMP=${BUILD_ID}
    fi
    BOOT_IMG="boot-$BOARD-$TIMESTAMP.ext4"
    truncate -s "$BOOT_SIZE" "$BOOT_IMG"
    ROOT_IMG="root-$BOARD-$TIMESTAMP.ext4"
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
    "deb https://mirror.iscas.ac.cn/revyos/revyos-gles-21/ revyos-gles-21 main" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-base/ sid main contrib non-free non-free-firmware" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-kernels/ revyos-kernels main" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-addons/ revyos-addons main"

    # move /boot contents to other place
    mv -v "$CHROOT_TARGET"/boot/* "$CHROOT_TARGET"/mnt/

    # Mount chroot path
    mount "$BOOT_IMG" "$CHROOT_TARGET"/boot
    mount -t proc /proc "$CHROOT_TARGET"/proc
    mount -B /sys "$CHROOT_TARGET"/sys
    mount -B /run "$CHROOT_TARGET"/run
    mount -B /dev "$CHROOT_TARGET"/dev
    mount -B /dev/pts "$CHROOT_TARGET"/dev/pts
    mount -t tmpfs tmpfs "$CHROOT_TARGET"/tmp
    mount -t tmpfs tmpfs "$CHROOT_TARGET"/var/tmp
    mount -t tmpfs tmpfs "$CHROOT_TARGET"/var/cache/apt/archives/

    # move boot contents back to /boot
    mv -v "$CHROOT_TARGET"/mnt/* "$CHROOT_TARGET"/boot/

    # apt update
    chroot "$CHROOT_TARGET" sh -c "apt update"
}

make_bootable()
{
    # Install kernel
    chroot "$CHROOT_TARGET" sh -c "apt install -y $KERNEL"

    # Add update-u-boot config
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_PROMPT=\"2\"' >> /etc/default/u-boot"
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_MENU_LABEL=\"RevyOS GNU/Linux\"' >> /etc/default/u-boot"
    if [ "${BOARD}" == "console" ]; then
        chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_PARAMETERS=\"console=ttyS0,115200 rootwait rw earlycon clk_ignore_unused loglevel=7 eth=$ethaddr rootrwoptions=rw,noatime rootrwreset=yes fbcon=rotate:1\"' >> /etc/default/u-boot"
    else
        chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_PARAMETERS=\"console=ttyS0,115200 rootwait rw earlycon clk_ignore_unused loglevel=7 eth=$ethaddr rootrwoptions=rw,noatime rootrwreset=yes\"' >> /etc/default/u-boot"
    fi
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_FDT_DIR=\"/dtbs/linux-image-\"' >> /etc/default/u-boot"
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_ROOT=\"root=PARTUUID=80a5a8e9-c744-491a-93c1-4f4194fd690a\"' >> /etc/default/u-boot"

    # Update extlinux config
    chroot "$CHROOT_TARGET" sh -c "u-boot-update"
}

after_mkrootfs()
{
    # Add timestamp file in /etc
    if [ ! -f revyos-release ]; then
        echo "$TIMESTAMP" > rootfs/etc/revyos-release
    else
        cp -v revyos-release rootfs/etc/revyos-release
    fi

    # copy addons to rootfs
    cp -rp addons/lib/firmware rootfs/lib/

    if [ "${BOARD}" == "lpi4a" ]; then
        echo "lpi4a specific: Add RTL8723DS Service"
        # Add Bluetooth firmware and service
        cp -rp addons/lpi4a-bt/rootfs/usr/local/bin/rtk_hciattach rootfs/usr/local/bin/
        cp -rp addons/etc/systemd/system/auto-hciattach.service rootfs/etc/systemd/system/
    fi
    if [ "${BOARD}" == "console" ]; then
        echo "console specific: Add AIC8800 Bluetooth Service"
        # Add Bluetooth firmware and service
        cp -rp addons/lpi4a-bt/rootfs/usr/local/bin/rtk_hciattach rootfs/usr/local/bin/
        cp -rp addons/etc/systemd/system/auto-hciattach.service rootfs/etc/systemd/system/
    fi

    # Add firstboot service
    cp -rp addons/etc/systemd/system/firstboot.service rootfs/etc/systemd/system/
    cp -rp addons/opt/firstboot.sh rootfs/opt/

    # Install system services
    chroot "$CHROOT_TARGET" sh -c "systemctl enable pvrsrvkm"
    chroot "$CHROOT_TARGET" sh -c "systemctl enable firstboot"
    if [ "${BOARD}" == "lpi4a" ] || [ "${BOARD}" == "console" ]; then
        echo "lpi4a specific: Enable auto-hciattach Service"
        chroot "$CHROOT_TARGET" sh -c "systemctl enable auto-hciattach"
    fi

    # Use iptables-legacy for docker
    chroot "$CHROOT_TARGET" sh -c "update-alternatives --set iptables /usr/sbin/iptables-legacy"
    chroot "$CHROOT_TARGET" sh -c "update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy"

    # Chromium add "--no-sandbox --use-gl=egl" flags
    # replace "Exec=/usr/bin/chromium %U" to "Exec=/usr/bin/chromium --no-sandbox --use-gl=egl %U"
    sed -i "s/Exec=\/usr\/bin\/chromium/Exec=\/usr\/bin\/chromium --no-sandbox --use-gl=egl/gi" "$CHROOT_TARGET"/usr/share/applications/chromium.desktop

    # Temp add HDMI audio output on Volume control
    echo "load-module module-alsa-sink device=hw:0,2 tsched=0" >> "$CHROOT_TARGET"/etc/pulse/default.pa

    # Change xfce4-panel default web-browser icon to chromium
    sed -i 's/xfce4-web-browser.desktop/chromium.desktop/g' "$CHROOT_TARGET"/etc/xdg/xfce4/panel/default.xml 

    # Fix cann't connect bluetooth headphone
    sed -i 's/load-module module-bluetooth-policy/load-module module-bluetooth-policy auto_switch=false/g' "$CHROOT_TARGET"/etc/pulse/default.pa

    # Using on chip 2D accelerator for quicker window & menu drawing
    if [ "${BOARD}" == "lpi4a" ] || [ "${BOARD}" == "ahead" ]; then
        cat << EOF > "$CHROOT_TARGET"/usr/share/X11/xorg.conf.d/10-gc620.conf
Section "Device"
	Identifier "dc8200"
	Driver "thead"
EndSection
EOF
    fi

    if [ "${BOARD}" == "lpi4amain" ]; then
        # No space left on device
        echo "skip install mpv parole th1520-vpu libgl4es"
    else
        # Install other packages
        chroot "$CHROOT_TARGET" sh -c "apt install -y mpv parole th1520-vpu libgl4es"
    fi

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

    # Copy files for Console4A
    if [ "${BOARD}" == "console" ]; then
        echo "Console4A specific: Copy files for Console4A"
        cp -rp addons/LicheeConsole4A/* rootfs/opt/
        # Install autostarts
        cp -rp addons/LicheeConsole4A/display-setup.desktop rootfs/etc/xdg/autostart/

        # Rotate lightdm screen using /opt/display-setup.sh
        sed -i 's/#greeter-setup-script=/greeter-setup-script=\/opt\/display-setup.sh/g' "$CHROOT_TARGET"/etc/lightdm/lightdm.conf 
    fi

    # Set locale to en_US.UTF-8 UTF-8
    chroot "$CHROOT_TARGET" sh -c "echo 'locales locales/default_environment_locale select en_US.UTF-8' | debconf-set-selections"
    chroot "$CHROOT_TARGET" sh -c "echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8' | debconf-set-selections"
    chroot "$CHROOT_TARGET" sh -c "rm /etc/locale.gen"
    chroot "$CHROOT_TARGET" sh -c "dpkg-reconfigure --frontend noninteractive locales"

    # Set default timezone to Asia/Shanghai
    chroot "$CHROOT_TARGET" sh -c "ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime"
    echo "Asia/Shanghai" > rootfs/etc/timezone

    # Set up fstab
    chroot "$CHROOT_TARGET" sh -c "echo '/dev/mmcblk0p3 /   auto    defaults    1 1' >> /etc/fstab"
    chroot "$CHROOT_TARGET" sh -c "echo '/dev/mmcblk0p2 /boot   auto    defaults    0 0' >> /etc/fstab"

    # apt update
    # chroot "$CHROOT_TARGET" sh -c "apt update"
    
    # Add user
    chroot "$CHROOT_TARGET" sh -c "useradd -m -s /bin/bash -G adm,cdrom,floppy,sudo,input,audio,dip,video,plugdev,netdev,bluetooth,lp debian"
    chroot "$CHROOT_TARGET" sh -c "echo 'debian:debian' | chpasswd"

    if [ "${BOARD}" == "lpi4a" ] || [ "${BOARD}" == "console" ]; then
        echo "lpi4a specific: Add sipeed user"
        chroot "$CHROOT_TARGET" sh -c "useradd -m -s /bin/bash -G adm,cdrom,floppy,sudo,input,audio,dip,video,plugdev,netdev,bluetooth,lp sipeed"
        chroot "$CHROOT_TARGET" sh -c "echo 'sipeed:licheepi' | chpasswd"
    fi

    # Change hostname
    chroot "$CHROOT_TARGET" sh -c "echo ${BOARD} > /etc/hostname"
    chroot "$CHROOT_TARGET" sh -c "echo 127.0.1.1 ${BOARD} >> /etc/hosts"

    # remove openssh keys
    rm -v rootfs/etc/ssh/ssh_host_*

    if [ "${BOARD}" == "lpi4amain" ]; then
        echo "lpi4amain No GPU: Disable lightdm"
	# lpi4a-main No GPU
        chroot "$CHROOT_TARGET" sh -c "systemctl disable lightdm"
        # Install perf-th1520 (new perf for c9xx pmu)
        cp -rp addons/lpi4amain/perf-th1520 rootfs/bin
    fi

    # refresh so libs
    chroot "$CHROOT_TARGET" sh -c "rm -v /etc/ld.so.cache"
    chroot "$CHROOT_TARGET" sh -c "ldconfig"

    # Clean apt caches
    rm -r "$CHROOT_TARGET"/var/lib/apt/lists/*
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

calculate_md5()
{
    echo "Calculate MD5 for outputs..."
		if [ ! -z $IMAGE_FILE ] && [ -f $IMAGE_FILE ]; then
			echo "$(md5sum $IMAGE_FILE)"
		fi
		if [ ! -z $BOOT_IMG ] && [ -f $BOOT_IMG ]; then
			echo "$(md5sum $BOOT_IMG)"
		fi
		if [ ! -z $ROOT_IMG ] && [ -f $ROOT_IMG ]; then
			echo "$(md5sum $ROOT_IMG)"
		fi
}

main()
{
    if [[ ! -v BOARD ]]; then
        echo "env BOARD is not set!"
    elif [[ -z "$BOARD" ]]; then
        echo "env BOARD is set to the empty string!"
    else
        echo "BOARD is: $BOARD"
    fi

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
		echo "Build succeed."
        calculate_md5
	else
        echo "Interrupted exit $?."
		unmount_image
		cleanup_env
		if [ ! -z $IMAGE_FILE ] && [ -f $IMAGE_FILE ]; then
			echo "delete image $IMAGE_FILE ..."
			rm -v "$IMAGE_FILE"
		fi
		if [ ! -z $BOOT_IMG ] && [ -f $BOOT_IMG ]; then
			echo "delete image $BOOT_IMG ..."
			rm -v "$BOOT_IMG"
		fi
		if [ ! -z $ROOT_IMG ] && [ -f $ROOT_IMG ]; then
			echo "delete image $ROOT_IMG ..."
			rm -v "$ROOT_IMG"
		fi
		echo "Build failed."
	fi
}

main
