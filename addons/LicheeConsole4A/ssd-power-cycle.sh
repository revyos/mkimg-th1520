#!/bin/sh

# if you need use ssd as root, you need add this script into your initramfs
# todo: move into uboot or kernel

cd /sys/class/gpio/
echo 313 > export
cd gpio313
echo out > direction
echo 0 > value
echo 1 > value
