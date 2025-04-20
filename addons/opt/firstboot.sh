#!/bin/sh

# formatand enable swap partition
mkswap /dev/mmcblk0p3
swapon -a

# mount non-rootfs
mount /dev/mmcblk0p2 /boot

# regenerate fstab
genfstab -t PARTUUID / > /etc/fstab
update-initramfs -u

# whiptail --infobox "Generating SSH Host keys..." 20 60

# regenerate openssh host keys
dpkg-reconfigure openssh-server

# set hosts
echo "127.0.1.1 $(hostname)" >> /etc/hosts

# whiptail --infobox "Firstboot Done. Rebooting in 3 seconds..." 20 60
# sleep 3
# reboot
