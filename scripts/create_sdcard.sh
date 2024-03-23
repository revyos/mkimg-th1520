#!/bin/bash

create_sdcard()
{
    SD_TARGET=sdcard.cfg

    cp -vf sdcard_template.cfg ${SD_TARGET}

    sed -i "s/boot_template.ext4/${BOOT_IMG}/g" ${SD_TARGET}
    sed -i "s/root_template.ext4/${ROOT_IMG}/g" ${SD_TARGET}
    sed -i "s/th1520_sdcard_template/sdcard-$BOARD-$TIMESTAMP/g" ${SD_TARGET}

    genimage --config ${SD_TARGET} \
        --inputpath $(pwd) \
        --outputpath $(pwd) \
        --rootpath="$(mktemp -d)"
}
