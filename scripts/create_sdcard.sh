#!/bin/bash

create_sdcard()
{
    SD_TARGET=sdcard.cfg
    SD_NAME=sdcard-$BOARD-$TIMESTAMP.img

    cp -vf sdcard_template.cfg ${SD_TARGET}

    sed -i "s/boot_template.ext4/${BOOT_IMG}/g" ${SD_TARGET}
    sed -i "s/root_template.ext4/${ROOT_IMG}/g" ${SD_TARGET}
    sed -i "s/th1520_sdcard_template/sdcard-$BOARD-$TIMESTAMP/g" ${SD_TARGET}

    genimage --config ${SD_TARGET} \
        --inputpath $(pwd) \
        --outputpath $(pwd) \
        --rootpath="$(mktemp -d)"

    losetup -P "${LOOP_DEVICE}" ${SD_NAME}

    mount "${LOOP_DEVICE}"p4 $CHROOT_TARGET
    mount "${LOOP_DEVICE}"p2 $CHROOT_TARGET/boot
    # Update fstab
    sed -i "s/mmcblk0/mmcblk1/g" $CHROOT_TARGET/etc/fstab
    # Update firstboot
    sed -i "s/mmcblk0/mmcblk1/g" $CHROOT_TARGET/opt/firstboot.sh
    # Update uboot
    sed -i "s/${EMMC_ROOT_UUID}/${SDCARD_ROOT_UUID}/g" $CHROOT_TARGET/etc/default/u-boot
    sed -i "s/${EMMC_ROOT_UUID}/${SDCARD_ROOT_UUID}/g" $CHROOT_TARGET/boot/extlinux/extlinux.conf

    # clean sdcard
    umount -l $CHROOT_TARGET
    losetup -d "${LOOP_DEVICE}"
}
