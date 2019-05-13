BeagleBoard.org BeagleBone AI

Description
===========

This configuration will build a complete image for BeagleBoard.org
BeagleBone AI.

How to build it
===============

Select the default configuration for the target:
$ make beagleboneai_defconfig

Optional: modify the configuration:
$ make menuconfig

Build:
$ make

Result of the build
===================
output/images/
├── 
├── 
└── 

To copy the image file to the sdcard use dd:
$ dd if=output/images/sdcard.img of=/dev/XXX

Tested hardware
===============
(none)
