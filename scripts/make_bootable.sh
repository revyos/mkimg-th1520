#!/bin/bash

make_bootable()
{
    chroot "$CHROOT_TARGET" /bin/bash << EOF
# Install kernel
apt install -y $KERNEL
EOF

    # Add update-u-boot config
    cat > $CHROOT_TARGET/etc/default/u-boot << EOF
U_BOOT_PROMPT="2"
U_BOOT_MENU_LABEL="RevyOS GNU/Linux"
U_BOOT_FDT_DIR="/dtbs/linux-image-"
U_BOOT_ROOT="root=PARTUUID=80a5a8e9-c744-491a-93c1-4f4194fd690a"
U_BOOT_PARAMETERS="console=ttyS0,115200 rootwait rw earlycon clk_ignore_unused loglevel=7 eth=$ethaddr rootrwoptions=rw,noatime rootrwreset=yes"
EOF

    # For console4a rotate
    if [ "${BOARD}" == "${BOARD_CONSOLE4A}" ]; then
        sed -i 's/rootrwreset=yes/rootrwreset=yes fbcon=rotate:1/' $CHROOT_TARGET/etc/default/u-boot
    fi

    # Update extlinux config
    chroot "$CHROOT_TARGET" /bin/bash << EOF
u-boot-update
EOF
}
