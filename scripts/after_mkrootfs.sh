#!/bin/bash

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

    if [ "${BOARD}" == "${BOARD_LPI4A}" ]; then
        echo "lpi4a specific: Add RTL8723DS Service"
        # Add Bluetooth firmware and service
        cp -rp addons/lpi4a-bt/rootfs/usr/local/bin/rtk_hciattach rootfs/usr/local/bin/
        cp -rp addons/etc/systemd/system/auto-hciattach.service rootfs/etc/systemd/system/
    fi
    if [ "${BOARD}" == "${BOARD_CONSOLE4A}" ]; then
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
    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ]; then
        echo "lpi4a specific: Enable auto-hciattach Service"
        chroot "$CHROOT_TARGET" sh -c "systemctl enable auto-hciattach"
    fi

    # Use iptables-legacy for docker
    chroot "$CHROOT_TARGET" sh -c "update-alternatives --set iptables /usr/sbin/iptables-legacy"
    chroot "$CHROOT_TARGET" sh -c "update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy"

    # Chromium add "--no-sandbox --use-gl=egl" flags
    # replace "Exec=/usr/bin/chromium %U" to "Exec=/usr/bin/chromium --no-sandbox --use-gl=egl %U"
    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ]; then
        sed -i "s/Exec=\/usr\/bin\/chromium/Exec=\/usr\/bin\/chromium --no-sandbox --use-gl=egl/gi" "$CHROOT_TARGET"/usr/share/applications/chromium.desktop

        # Temp add HDMI audio output on Volume control
        echo "load-module module-alsa-sink device=hw:0,2 tsched=0" >> "$CHROOT_TARGET"/etc/pulse/default.pa

        # Change xfce4-panel default web-browser icon to chromium
        sed -i 's/xfce4-web-browser.desktop/chromium.desktop/g' "$CHROOT_TARGET"/etc/xdg/xfce4/panel/default.xml 

        # Fix cann't connect bluetooth headphone
        sed -i 's/load-module module-bluetooth-policy/load-module module-bluetooth-policy auto_switch=false/g' "$CHROOT_TARGET"/etc/pulse/default.pa
    fi

    # Using on chip 2D accelerator for quicker window & menu drawing
    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_AHEAD}" ]; then
        cat << EOF > "$CHROOT_TARGET"/usr/share/X11/xorg.conf.d/10-gc620.conf
Section "Device"
	Identifier "dc8200"
	Driver "thead"
EndSection
EOF
    fi

    if [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        # No space left on device
        echo "skip install mpv parole th1520-vpu libgl4es"
    else
        # Install other packages
        chroot "$CHROOT_TARGET" sh -c "apt install -y mpv parole th1520-vpu libgl4es"
    fi

    # Setup branding related
    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ]; then
        chroot "$CHROOT_TARGET" sh -c "apt install -y $BRANDING "
        rm -vr "$CHROOT_TARGET"/etc/update-motd.d
        cp -rp addons/etc/update-motd.d "$CHROOT_TARGET"/etc/
    elif [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1029394
        chroot "$CHROOT_TARGET" sh -c "apt install -y lsb-release figlet "
        rm -vr "$CHROOT_TARGET"/etc/update-motd.d
        cp -rp addons/etc/update-motd.d "$CHROOT_TARGET"/etc/
    fi
    if [ "${BOARD}" != "${BOARD_LPI4A_MAINLINE}" ]; then
        # Wallpaper
        cp -rp addons/usr/share/images/ruyisdk "$CHROOT_TARGET"/usr/share/images/
        chroot "$CHROOT_TARGET" sh -c "rm -v /usr/share/images/desktop-base/desktop-background"
        chroot "$CHROOT_TARGET" sh -c "rm -v /usr/share/images/desktop-base/login-background.svg"
        chroot "$CHROOT_TARGET" sh -c "ln -s /usr/share/images/ruyisdk/ruyi-1-1920x1080.png /usr/share/images/desktop-base/desktop-background"
        chroot "$CHROOT_TARGET" sh -c "ln -s /usr/share/images/ruyisdk/ruyi-2-1920x1080.png /usr/share/images/desktop-base/login-background.svg"
    fi

    # lpi4amain related (disable GPU, add perf)
    if [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        # lpi4a-main No GPU
        if ( chroot "$CHROOT_TARGET" sh -c "systemctl list-unit-files lightdm.service" ); then
            echo "lpi4amain No GPU: Disable lightdm"
            chroot "$CHROOT_TARGET" sh -c "systemctl disable lightdm"
        fi
        # Install perf-th1520 (new perf for c9xx pmu)
        cp -rp addons/lpi4amain/perf-th1520 rootfs/bin
    fi

    # Copy files for Console4A
    if [ "${BOARD}" == "${BOARD_CONSOLE4A}" ]; then
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
    echo "Asia/Shanghai" > $CHROOT_TARGET/etc/timezone

    # Set up fstab
    chroot $CHROOT_TARGET /bin/bash << EOF
echo '/dev/mmcblk0p4 /   auto    defaults    1 1' >> /etc/fstab
echo '/dev/mmcblk0p2 /boot   auto    defaults    0 0' >> /etc/fstab

exit
EOF

    # apt update
    # chroot "$CHROOT_TARGET" sh -c "apt update"
    
    # Add user
    chroot "$CHROOT_TARGET" sh -c "useradd -m -s /bin/bash -G adm,cdrom,floppy,sudo,input,audio,dip,video,plugdev,netdev,bluetooth,lp debian"
    chroot "$CHROOT_TARGET" sh -c "echo 'debian:debian' | chpasswd"

    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ]; then
        echo "lpi4a specific: Add sipeed user"
        chroot "$CHROOT_TARGET" sh -c "useradd -m -s /bin/bash -G adm,cdrom,floppy,sudo,input,audio,dip,video,plugdev,netdev,bluetooth,lp sipeed"
        chroot "$CHROOT_TARGET" sh -c "echo 'sipeed:licheepi' | chpasswd"
    fi

    # Change hostname
    chroot $CHROOT_TARGET /bin/bash << EOF
echo revyos-${BOARD} > /etc/hostname

exit
EOF

    # remove openssh keys
    rm -v rootfs/etc/ssh/ssh_host_*

    # refresh so libs
    chroot "$CHROOT_TARGET" sh -c "rm -v /etc/ld.so.cache"
    chroot "$CHROOT_TARGET" sh -c "ldconfig"

    # Clean apt caches
    rm -r "$CHROOT_TARGET"/var/lib/apt/lists/*
}