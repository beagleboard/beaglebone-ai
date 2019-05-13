#!/bin/sh
# post-build.sh for BeagleBoard.org BeagleBone AI
# 2018-2019, Jason Kridner <jdk@ti.com>

BOARD_DIR="$(dirname $0)"

mkdir -p $TARGET_DIR/boot
cp $BINARIES_DIR/*.dtb $TARGET_DIR/boot/
cp $BINARIES_DIR/zImage $TARGET_DIR/boot/
echo "$(git show -s --date=short --format='Buildroot beagle-tester %cd %h')" > $TARGET_DIR/etc/dogtag
