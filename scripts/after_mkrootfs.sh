#!/bin/bash

after_mkrootfs()
{
    # Add timestamp file in /etc
    if [ ! -f revyos-release ]; then
        echo "$TIMESTAMP" > "$CHROOT_TARGET"/etc/revyos-release
    else
        cp -v revyos-release "$CHROOT_TARGET"/etc/revyos-release
    fi

    # copy addons to rootfs
    cp -rp addons/lib/firmware "$CHROOT_TARGET"/lib/

    # Add chromium bookmark policy
    # See https://github.com/revyos/revyos/issues/104
    mkdir -p "$CHROOT_TARGET"/usr/share/chromium
    cp -p addons/chromium/initial_bookmarks.html "$CHROOT_TARGET"/usr/share/chromium/

    if [ "${BOARD}" == "${BOARD_LPI4A}" ]; then
        echo "lpi4a specific: Add RTL8723DS Service"
        # Add Bluetooth firmware and service
        cp -rp addons/lpi4a-bt/rootfs/usr/local/bin/rtk_hciattach "$CHROOT_TARGET"/usr/local/bin/
        cp -rp addons/etc/systemd/system/auto-hciattach.service "$CHROOT_TARGET"/etc/systemd/system/
    fi
    if [ "${BOARD}" == "${BOARD_CONSOLE4A}" ] || [ "${BOARD}" == "${BOARD_LAPTOP4A}" ]; then
        echo "console specific: Add AIC8800 Bluetooth Service"
        # Add Bluetooth firmware and service
        cp -rp addons/lpi4a-bt/rootfs/usr/local/bin/rtk_hciattach "$CHROOT_TARGET"/usr/local/bin/
        cp -rp addons/etc/systemd/system/auto-hciattach.service "$CHROOT_TARGET"/etc/systemd/system/
    fi

    # # Add firstboot service
    # cp -rp addons/etc/systemd/system/firstboot.service "$CHROOT_TARGET"/etc/systemd/system/
    # cp -rp addons/opt/firstboot.sh "$CHROOT_TARGET"/opt/

    # Install system services
    chroot "$CHROOT_TARGET" /bin/bash << EOF
systemctl enable pvrsrvkm
EOF

    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ] || [ "${BOARD}" == "${BOARD_LAPTOP4A}" ]; then
        echo "lpi4a specific: Enable auto-hciattach Service"
        chroot "$CHROOT_TARGET" /bin/bash << EOF
systemctl enable auto-hciattach
EOF
    fi

    # Chromium add "--no-sandbox --use-gl=egl" flags
    # replace "Exec=/usr/bin/chromium %U" to "Exec=/usr/bin/chromium --no-sandbox --use-gl=egl %U"
    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_AHEAD}" ] || [ "${BOARD}" == "${BOARD_MELES}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ] || [ "${BOARD}" == "${BOARD_LAPTOP4A}" ]; then
        chroot "$CHROOT_TARGET" /bin/bash << EOF
sed -i "s/Exec=\/usr\/bin\/chromium/Exec=\/usr\/bin\/chromium --no-sandbox --use-gl=egl/gi" \
        /usr/share/applications/chromium.desktop
# Temp add HDMI audio output on Volume control
echo "load-module module-alsa-sink device=hw:0,2 tsched=0" >> /etc/pulse/default.pa

# Change xfce4-panel default web-browser icon to chromium
sed -i 's/xfce4-web-browser.desktop/chromium.desktop/g' /etc/xdg/xfce4/panel/default.xml

# Fix cann't connect bluetooth headphone
sed -i 's/load-module module-bluetooth-policy/load-module module-bluetooth-policy auto_switch=false/g' \
        /etc/pulse/default.pa
EOF
    fi

    # Using on chip 2D accelerator for quicker window & menu drawing
    # Note: on Console 4A, DSI+HDMI dual screen will have problem for now because of xfce4-display-settings
    # (xfce4-display-settings can't handle rotated DSI screen + HDMI screen correctly, using xrandr or arandr is fine)
    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ] || [ "${BOARD}" == "${BOARD_LAPTOP4A}" ] || [ "${BOARD}" == "${BOARD_AHEAD}" ] || [ "${BOARD}" == "${BOARD_MELES}" ]; then
        cat << EOF > "$CHROOT_TARGET"/usr/share/X11/xorg.conf.d/10-gc620.conf
Section "Device"
	Identifier "dc8200"
	Driver "thead"
EndSection
EOF
    fi

    if [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        # No space left on device
        echo "skip install mpv parole th1520-vpu libgl4es th1520-npu"
    else
        # Install other packages
        chroot "$CHROOT_TARGET" /bin/bash << EOF
apt install -y mpv parole th1520-vpu libgl4es th1520-npu
EOF
    fi

    # Setup branding related
    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ] || [ "${BOARD}" == "${BOARD_LAPTOP4A}" ]; then
        chroot "$CHROOT_TARGET" /bin/bash << EOF
apt install -y $BRANDING
rm -vr /etc/update-motd.d
EOF
        cp -rp addons/etc/update-motd.d "$CHROOT_TARGET"/etc/
    elif [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1029394
        chroot "$CHROOT_TARGET" /bin/bash << EOF
apt install -y lsb-release figlet
rm -vr /etc/update-motd.d
EOF
        cp -rp addons/etc/update-motd.d "$CHROOT_TARGET"/etc/
    fi
    if [ "${BOARD}" != "${BOARD_LPI4A_MAINLINE}" ]; then
        # Wallpaper
        cp -rp addons/usr/share/images/ruyisdk "$CHROOT_TARGET"/usr/share/images/
        chroot "$CHROOT_TARGET" /bin/bash << EOF
rm -v /usr/share/images/desktop-base/desktop-background
rm -v /usr/share/images/desktop-base/login-background.svg
ln -s /usr/share/images/ruyisdk/ruyi-1-1920x1080.png /usr/share/images/desktop-base/desktop-background
ln -s /usr/share/images/ruyisdk/ruyi-2-1920x1080.png /usr/share/images/desktop-base/login-background.svg
EOF
    fi
    if [ "${BOARD}" == "${BOARD_LPI4A}" ] || [ "${BOARD}" == "${BOARD_CONSOLE4A}" ] || [ "${BOARD}" == "${BOARD_LAPTOP4A}" ]; then
        cp -rp addons/usr/share/alsa "$CHROOT_TARGET"/usr/share/
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

    # copy cloud-init config
    cp -rp addons/etc/cloud/cloud.cfg.d/00_nocloud.cfg "$CHROOT_TARGET"/etc/cloud/cloud.cfg.d/00_nocloud.cfg
    cp -rp addons/etc/cloud/revyos-data "$CHROOT_TARGET"/etc/cloud/
    sed -i "s/hostname: .*$/hostname: revyos-${BOARD}/g" "$CHROOT_TARGET"/etc/cloud/revyos-data/user-data
}
