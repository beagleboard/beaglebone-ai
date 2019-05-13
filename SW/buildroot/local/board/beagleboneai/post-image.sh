#!/bin/sh
# post-image.sh for BeagleBoard.org BeagleBone AI
# 2014, Marcin Jabrzyk <marcin.jabrzyk@gmail.com>
# 2016, Lothar Felten <lothar.felten@gmail.com>
# 2018-2019, Jason Kridner <jdk@ti.com>

BOARD_DIR="$(dirname $0)"

GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
GIT_VERSION="$(git describe --abbrev=6 --dirty --always --tags)"

rm -rf "${GENIMAGE_TMP}"

genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

dd if=${BINARIES_DIR}/MLO of=${BINARIES_DIR}/sdcard.img bs=128k count=2 seek=1 conv=notrunc
dd if=${BINARIES_DIR}/u-boot-dtb.img of=${BINARIES_DIR}/sdcard.img bs=384k count=4 seek=1 conv=notrunc
xz -c ${BINARIES_DIR}/sdcard.img > ${BINARIES_DIR}/beagle-tester-beagleboneai-${GIT_VERSION}.img.xz
rm -f ${BINARIES_DIR}/sdcard.img

