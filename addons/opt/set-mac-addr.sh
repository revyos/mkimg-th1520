#!/bin/sh

# how to use this script:
# use your phone scan qrcode on lm4a board
# then copy content from qrcode, then run:
# sh set-mac-addr.sh <CONTENT_FROM_QRCODE>

set -e -u

hex2mac() {
        MAC=""
        seq 2 2 12 | while read i
        do
                echo -n ${1} | head -c $i | tail -c 2
                if [ $i != 12 ]
                then
                        echo -n ':'
                fi
        done | tr '[:upper:]' '[:lower:]'
}

INFO="${1}"
NAME=$(echo $INFO | awk -F'-' '{print $1}')
MAC0HEX=$(echo $INFO | awk -F'-' '{print $3}')
MAC1HEX=$(echo $MAC0HEX 1 | dc -e '16o16i?+p')

if [ "$NAME" != "LM4A0" ]
then
        echo "BAD INPUT"
        exit 1
fi

MAC0=$(hex2mac $MAC0HEX)
MAC1=$(hex2mac $MAC1HEX)

echo "end0: $MAC0"
echo "end1: $MAC1"

fw_setenv ethaddr $MAC0
fw_setenv eth1addr $MAC1

fw_printenv ethaddr
fw_printenv eth1addr

# hostname with mac address
OLD_HOSTNAME=$(cat /etc/hostname)
NEW_HOSTNAME="lc4a$(echo $MAC0 | tr -d ':\n' | tail -c 4)"

for file in /etc/hostname /etc/hosts
do
        sed -i -e "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" $file
done
nmcli general hostname "$NEW_HOSTNAME"
hostname "$NEW_HOSTNAME"

# restart avahi daemon
systemctl restart avahi-daemon
