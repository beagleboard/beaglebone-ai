Built using https://github.com/beagleboard/buildroot

Branch 'beagle-tester'
Commit c0319b12a3018d36959f4a0ec5ab007acd02dc39

make O=/path/to/beaglebone-ai/SW/buildroot -C /path/to/buildroot BR2_EXTERNAL=/path/to/beaglebone-ai/SW/buildroot/local/ beagleboneai_defconfig
make

Example:
make O=/home/jkridner/beaglebone-ai/SW/buildroot -C /home/jkridner/buildroot BR2_EXTERNAL=/home/jkridner/beaglebone-ai/SW/buildroot/local/ beagleboneai_defconfig
make
