#!/bin/bash

# use all emmc free space for rootfs
parted -s /dev/mmcblk0 "resizepart 3 -0"
# resize root filesystem
resize2fs /dev/mmcblk0p2
resize2fs /dev/mmcblk0p3

# hostname with mac address
HOSTNAME="lpi4a-$(cat /sys/class/net/end0/address | tr -d ':\n' | tail -c 4)"
for file in /etc/hostname /etc/hosts
do
        sed -i -e "s/lpi4a/$HOSTNAME/g" $file
done
nmcli general hostname "$HOSTNAME"
hostname "$HOSTNAME"

# enable & start avahi daemon
systemctl enable avahi-daemon
systemctl restart avahi-daemon

# regenerate openssh host keys
dpkg-reconfigure openssh-server
