#!/bin/bash

# use all emmc free space for rootfs
parted -s /dev/mmcblk0 "resizepart 3 -0"
# resize root filesystem
resize2fs /dev/mmcblk0p2
resize2fs /dev/mmcblk0p3

# regenerate openssh host keys
dpkg-reconfigure openssh-server