#!/bin/bash

make_bootable()
{
    # Install kernel
    chroot "$CHROOT_TARGET" sh -c "apt install -y $KERNEL"

    # Add update-u-boot config
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_PROMPT=\"2\"' >> /etc/default/u-boot"
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_MENU_LABEL=\"RevyOS GNU/Linux\"' >> /etc/default/u-boot"
    if [ "${BOARD}" == "${BOARD_CONSOLE4A}" ]; then
        chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_PARAMETERS=\"console=ttyS0,115200 rootwait rw earlycon clk_ignore_unused loglevel=7 eth=$ethaddr rootrwoptions=rw,noatime rootrwreset=yes fbcon=rotate:1\"' >> /etc/default/u-boot"
    else
        chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_PARAMETERS=\"console=ttyS0,115200 rootwait rw earlycon clk_ignore_unused loglevel=7 eth=$ethaddr rootrwoptions=rw,noatime rootrwreset=yes\"' >> /etc/default/u-boot"
    fi
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_FDT_DIR=\"/dtbs/linux-image-\"' >> /etc/default/u-boot"
    chroot "$CHROOT_TARGET" sh -c "echo 'U_BOOT_ROOT=\"root=PARTUUID=80a5a8e9-c744-491a-93c1-4f4194fd690a\"' >> /etc/default/u-boot"

    # Update extlinux config
    chroot "$CHROOT_TARGET" sh -c "u-boot-update"
}