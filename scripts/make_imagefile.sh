#!/bin/bash

make_imagefile()
{
    # Prepare /etc/revyos-release file
    if [ -f revyos-release ]; then
        echo "Found revyos-release, using timestamp in this file."
        . ./revyos-release
        TIMESTAMP=${BUILD_ID}
    fi

    if [ "${BOARD}" == "${BOARD_MELES}" ]; then
        # Create TF Card image file
        IMAGE_FILE="sdcard-$BOARD-$TIMESTAMP.img"
        IMAGE_SIZE=
        truncate -s "$IMAGE_SIZE" "$IMAGE_FILE"

        # Create partitions
        sgdisk -og "$IMAGE_FILE"
        sgdisk -n 1:2048:+$BOOT_SIZE -c 1:"BOOT" -t 1:8300 "$IMAGE_FILE"
        sgdisk -n 2:0:+$ROOT_SIZE -c 2:"ROOT" -t 2:8300 -A 2:set:2 "$IMAGE_FILE"
        # #ENDSECTOR=$(sgdisk -E "$IMAGE_FILE")
        # sgdisk -n 3:0:"$ENDSECTOR" -c 3:"ROOT" -t 2:8300 -A 2:set:2 "$IMAGE_FILE"
        sgdisk -p "$IMAGE_FILE"
    else
        # Create separate partition files
        BOOT_IMG="boot-$BOARD-$TIMESTAMP.ext4"
        truncate -s "$BOOT_SIZE" "$BOOT_IMG"
        ROOT_IMG="root-$BOARD-$TIMESTAMP.ext4"
        truncate -s "$ROOT_SIZE" "$ROOT_IMG"
    fi
}