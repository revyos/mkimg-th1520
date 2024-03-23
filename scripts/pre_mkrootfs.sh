#!/bin/bash

pre_mkrootfs()
{
    if [ "${BOARD}" == "${BOARD_MELES}" ]; then
        # Mount image in loop device
	    losetup --partscan --find --show "$IMAGE_FILE"
	    LOOP_DEVICE=$(losetup -j "$IMAGE_FILE" | grep -o "/dev/loop[0-9]*")
        BOOT_IMG="$LOOP_DEVICE"p1
        ROOT_IMG="$LOOP_DEVICE"p2

        # Format partitions
        mkfs.ext4 -F "$BOOT_IMG"
        mkfs.ext4 -F "$ROOT_IMG"
    else
        # Format partitions
        mkfs.ext4 -F "$BOOT_IMG"
        mkfs.ext4 -F "$ROOT_IMG"
    fi

    # Mount loop device
    mkdir "$CHROOT_TARGET"
    mount "$ROOT_IMG" "$CHROOT_TARGET"
}