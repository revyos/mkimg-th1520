#!/bin/bash
set -e

# BOARD=${BOARD:-lpi4a} # lpi4a, ahead
BOOT_SIZE=500M
BOOT_IMG=""
ROOT_SIZE=4G
ROOT_IMG=""
CHROOT_TARGET=rootfs

LOOP_DEVICE=""
EFI_MOUNTPOINT=""
BOOT_MOUNTPOINT=""
ROOT_MOUNTPOINT=""

TIMESTAMP=$(date +%Y%m%d-%H%M%S)

source $(pwd)/scripts/boards_list.sh
source $(pwd)/scripts/packages_list.sh
source $(pwd)/scripts/make_rootfs.sh
source $(pwd)/scripts/make_bootable.sh
source $(pwd)/scripts/after_mkrootfs.sh

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
    check_board_vaild
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
