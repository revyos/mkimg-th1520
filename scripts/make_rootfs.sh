#!/bin/bash

make_rootfs()
{
    if [ "${BOARD}" == "${BOARD_LPI4A_MAINLINE}" ]; then
        PACKAGE_LIST="$KEYRINGS $GPU_DRIVER $BASE_TOOLS $EXTRA_TOOLS"
    else
        PACKAGE_LIST="$KEYRINGS $GPU_DRIVER $BASE_TOOLS $GRAPHIC_TOOLS $XFCE_DESKTOP $BENCHMARK_TOOLS $FONTS $INCLUDE_APPS $EXTRA_TOOLS $LIBREOFFICE"
    fi

    mmdebstrap --architectures=riscv64 \
    --include="$PACKAGE_LIST" \
    sid "$CHROOT_TARGET" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-gles-21/ revyos-gles-21 main" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-base/ sid main contrib non-free non-free-firmware" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-kernels/ revyos-kernels main" \
    "deb https://mirror.iscas.ac.cn/revyos/revyos-addons/ revyos-addons main"

    # move /boot contents to other place
    if [ ! -z "$(ls -A "$CHROOT_TARGET"/boot/)" ]; then
        mkdir "$CHROOT_TARGET"/mnt/boot
        mv -v "$CHROOT_TARGET"/boot/* "$CHROOT_TARGET"/mnt/boot/
    fi

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
    if [ ! -z "$(ls -A "$CHROOT_TARGET"/mnt/boot/)" ]; then
        mv -v "$CHROOT_TARGET"/mnt/boot/* "$CHROOT_TARGET"/boot/
        rmdir "$CHROOT_TARGET"/mnt/boot
    fi

    # apt update
    chroot "$CHROOT_TARGET" sh -c "apt update"
}