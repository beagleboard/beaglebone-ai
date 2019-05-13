#!/bin/sh -e
#
# Copyright (c) 2013-2017 Robert Nelson <robertcnelson@gmail.com>
# Copyright (c) 2019 Texas Instruments, Jason Kridner <jdk@ti.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

#Based off:
#https://github.com/beagleboard/meta-beagleboard/blob/master/meta-beagleboard-extras/recipes-support/usb-gadget/gadget-init/g-ether-load.sh

set -e
set -x

modprobe libcomposite
echo "device" > /sys/kernel/debug/48890000.usb/mode

usb_gadget="/sys/kernel/config/usb_gadget"

usb_idVendor="0x1d6b"
usb_idProduct="0x0104"
usb_bcdDevice="0x0404"
usb_bcdUSB="0x0300"

#usb0 mass_storage
usb_ms_cdrom=0
usb_ms_ro=1
usb_ms_stall=0
usb_ms_removable=1
usb_ms_nofua=1

usb_image_file="/var/local/bb_usb_mass_storage.img"

usb_iserialnumber="1234BBBK5678"
usb_iproduct="BeagleBone"
usb_imanufacturer="BeagleBoard.org"

mac_address="/proc/device-tree/ocp/ethernet@4a100000/slave@4a100200/mac-address"
if [ -f ${mac_address} ] && [ -f /usr/bin/hexdump ] ; then
	cpsw_0_mac=$(hexdump -v -e '1/1 "%02X" ":"' ${mac_address} | sed 's/.$//')

	#Some devices are showing a blank cpsw_0_mac [00:00:00:00:00:00], let's fix that up...
	if [ "x${cpsw_0_mac}" = "x00:00:00:00:00:00" ] ; then
		cpsw_0_mac="1C:BA:8C:A2:ED:68"
	fi
else
	#todo: generate random mac... (this is a development tre board in the lab...)
	cpsw_0_mac="1C:BA:8C:A2:ED:68"
fi

unset use_cached_cpsw_mac
if [ -f /etc/cpsw_0_mac ] ; then
	unset test_cpsw_0_mac
	test_cpsw_0_mac=$(cat /etc/cpsw_0_mac)
	if [ "x${cpsw_0_mac}" = "x${test_cpsw_0_mac}" ] ; then
		use_cached_cpsw_mac="true"
	else
		echo "${cpsw_0_mac}" > /etc/cpsw_0_mac || true
	fi
else
	echo "${cpsw_0_mac}" > /etc/cpsw_0_mac || true
fi

if [ "x${use_cached_cpsw_mac}" = "xtrue" ] && [ -f /etc/cpsw_1_mac ] ; then
	cpsw_1_mac=$(cat /etc/cpsw_1_mac)
else
	mac_address="/proc/device-tree/ocp/ethernet@4a100000/slave@4a100300/mac-address"
	if [ -f ${mac_address} ] && [ -f /usr/bin/hexdump ] ; then
		cpsw_1_mac=$(hexdump -v -e '1/1 "%02X" ":"' ${mac_address} | sed 's/.$//')

		#Some devices are showing a blank cpsw_1_mac [00:00:00:00:00:00], let's fix that up...
		if [ "x${cpsw_1_mac}" = "x00:00:00:00:00:00" ] ; then
			if [ -f /usr/bin/bc ] ; then
				mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

				cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
				#bc cuts off leading zero's, we need ten/ones value
				cpsw_res=$(echo "obase=16;ibase=16;$cpsw_0_6 + 102" | bc)

				cpsw_1_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
			else
				cpsw_1_mac="1C:BA:8C:A2:ED:70"
			fi
		fi
		echo "${cpsw_1_mac}" > /etc/cpsw_1_mac || true
	else
		#todo: generate random mac...
		cpsw_1_mac="1C:BA:8C:A2:ED:70"
		echo "${cpsw_1_mac}" > /etc/cpsw_1_mac || true
	fi
fi

if [ "x${use_cached_cpsw_mac}" = "xtrue" ] && [ -f /etc/cpsw_2_mac ] ; then
	cpsw_2_mac=$(cat /etc/cpsw_2_mac)
else
	if [ -f /usr/bin/bc ] ; then
		mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

		cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
		cpsw_1_6=$(echo ${cpsw_1_mac} | awk -F ':' '{print $6}')

		cpsw_add=$(echo "obase=16;ibase=16;$cpsw_0_6 + $cpsw_1_6" | bc)
		cpsw_div=$(echo "obase=16;ibase=16;$cpsw_add / 2" | bc)
		#bc cuts off leading zero's, we need ten/ones value
		cpsw_res=$(echo "obase=16;ibase=16;$cpsw_div + 100" | bc)

		cpsw_2_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
		echo "${log} uncached cpsw_2_mac: [${cpsw_2_mac}]"
	else
		cpsw_0_last=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}' | cut -c 2)
		cpsw_1_last=$(echo ${cpsw_1_mac} | awk -F ':' '{print $6}' | cut -c 2)
		mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-16)
		mac_1_prefix=$(echo ${cpsw_1_mac} | cut -c 1-16)
		#if cpsw_0_mac is even, add 1
		case "x${cpsw_0_last}" in
		x0)
			cpsw_2_mac="${mac_0_prefix}1"
			;;
		x2)
			cpsw_2_mac="${mac_0_prefix}3"
			;;
		x4)
			cpsw_2_mac="${mac_0_prefix}5"
			;;
		x6)
			cpsw_2_mac="${mac_0_prefix}7"
			;;
		x8)
			cpsw_2_mac="${mac_0_prefix}9"
			;;
		xA)
			cpsw_2_mac="${mac_0_prefix}B"
			;;
		xC)
			cpsw_2_mac="${mac_0_prefix}D"
			;;
		xE)
			cpsw_2_mac="${mac_0_prefix}F"
			;;
		*)
			#else, subtract 1 from cpsw_1_mac
			case "x${cpsw_1_last}" in
			xF)
				cpsw_2_mac="${mac_1_prefix}E"
				;;
			xD)
				cpsw_2_mac="${mac_1_prefix}C"
				;;
			xB)
				cpsw_2_mac="${mac_1_prefix}A"
				;;
			x9)
				cpsw_2_mac="${mac_1_prefix}8"
				;;
			x7)
				cpsw_2_mac="${mac_1_prefix}6"
				;;
			x5)
				cpsw_2_mac="${mac_1_prefix}4"
				;;
			x3)
				cpsw_2_mac="${mac_1_prefix}2"
				;;
			x1)
				cpsw_2_mac="${mac_1_prefix}0"
				;;
			*)
				#todo: generate random mac...
				cpsw_2_mac="1C:BA:8C:A2:ED:6A"
				;;
			esac
			;;
		esac
	fi
	echo "${cpsw_2_mac}" > /etc/cpsw_2_mac || true
fi

if [ "x${use_cached_cpsw_mac}" = "xtrue" ] && [ -f /etc/cpsw_3_mac ] ; then
	cpsw_3_mac=$(cat /etc/cpsw_3_mac)
else
	if [ -f /usr/bin/bc ] ; then
		mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

		cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
		#bc cuts off leading zero's, we need ten/ones value
		cpsw_res=$(echo "obase=16;ibase=16;$cpsw_0_6 + 103" | bc)

		cpsw_3_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
	else
		cpsw_3_mac="1C:BA:8C:A2:ED:71"
	fi
	echo "${cpsw_3_mac}" > /etc/cpsw_3_mac || true
fi

if [ "x${use_cached_cpsw_mac}" = "xtrue" ] && [ -f /etc/cpsw_4_mac ] ; then
	cpsw_4_mac=$(cat /etc/cpsw_4_mac)
else
	if [ -f /usr/bin/bc ] ; then
		mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

		cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
		#bc cuts off leading zero's, we need ten/ones value
		cpsw_res=$(echo "obase=16;ibase=16;$cpsw_0_6 + 104" | bc)

		cpsw_4_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
	else
		cpsw_4_mac="1C:BA:8C:A2:ED:72"
	fi
	echo "${cpsw_4_mac}" > /etc/cpsw_4_mac || true
fi

if [ "x${use_cached_cpsw_mac}" = "xtrue" ] && [ -f /etc/cpsw_5_mac ] ; then
	cpsw_5_mac=$(cat /etc/cpsw_5_mac)
else
	if [ -f /usr/bin/bc ] ; then
		mac_0_prefix=$(echo ${cpsw_0_mac} | cut -c 1-14)

		cpsw_0_6=$(echo ${cpsw_0_mac} | awk -F ':' '{print $6}')
		#bc cuts off leading zero's, we need ten/ones value
		cpsw_res=$(echo "obase=16;ibase=16;$cpsw_0_6 + 105" | bc)

		cpsw_5_mac=${mac_0_prefix}:$(echo ${cpsw_res} | cut -c 2-3)
	else
		cpsw_5_mac="1C:BA:8C:A2:ED:73"
	fi
	echo "${cpsw_5_mac}" > /etc/cpsw_5_mac || true
fi

echo "${log} cpsw_0_mac: [${cpsw_0_mac}]"
echo "${log} cpsw_1_mac: [${cpsw_1_mac}]"
echo "${log} cpsw_2_mac: [${cpsw_2_mac}]"
echo "${log} cpsw_3_mac: [${cpsw_3_mac}]"
echo "${log} cpsw_4_mac: [${cpsw_4_mac}]"
echo "${log} cpsw_5_mac: [${cpsw_5_mac}]"

if [ ! -f /etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service ] ; then
	ln -s /lib/systemd/system/serial-getty@.service /etc/systemd/system/getty.target.wants/serial-getty@ttyGS0.service
fi

echo "${log} Creating g_multi"
mkdir -p /sys/kernel/config/usb_gadget/g_multi
cd /sys/kernel/config/usb_gadget/g_multi

echo ${usb_bcdUSB} > bcdUSB
echo ${usb_idVendor} > idVendor # Linux Foundation
echo ${usb_idProduct} > idProduct # Multifunction Composite Gadget
echo ${usb_bcdDevice} > bcdDevice

#0x409 = english strings...
mkdir -p strings/0x409

echo ${usb_iserialnumber} > strings/0x409/serialnumber
echo ${usb_imanufacturer} > strings/0x409/manufacturer
echo ${usb_iproduct} > strings/0x409/product

mkdir -p functions/rndis.usb0
# first byte of address must be even
echo ${cpsw_2_mac} > functions/rndis.usb0/host_addr
echo ${cpsw_1_mac} > functions/rndis.usb0/dev_addr

# Starting with kernel 4.14, we can do this to match Microsoft's built-in RNDIS driver.
# Earlier kernels require the patch below as a work-around instead:
# https://github.com/beagleboard/linux/commit/e94487c59cec8ba32dc1eb83900297858fdc590b
echo EF > functions/rndis.usb0/class
echo 04 > functions/rndis.usb0/subclass
echo 01 > functions/rndis.usb0/protocol

# Add OS Descriptors for the latest Windows 10 rndiscmp.inf
# https://answers.microsoft.com/en-us/windows/forum/windows_10-networking-winpc/windows-10-vs-remote-ndis-ethernet-usbgadget-not/cb30520a-753c-4219-b908-ad3d45590447
# https://www.spinics.net/lists/linux-usb/msg107185.html
echo 1 > os_desc/use
echo 0xCD > os_desc/b_vendor_code
echo MSFT100 > os_desc/qw_sign
echo "RNDIS" > functions/rndis.usb0/os_desc/interface.rndis/compatible_id
echo "5162001" > functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id

mkdir -p configs/c.1
ln -s configs/c.1 os_desc
mkdir functions/rndis.usb0/os_desc/interface.rndis/Icons
echo 2 > functions/rndis.usb0/os_desc/interface.rndis/Icons/type
echo "%SystemRoot%\\system32\\shell32.dll,-233" > functions/rndis.usb0/os_desc/interface.rndis/Icons/data
mkdir functions/rndis.usb0/os_desc/interface.rndis/Label
echo 1 > functions/rndis.usb0/os_desc/interface.rndis/Label/type
echo "BeagleBone USB Ethernet" > functions/rndis.usb0/os_desc/interface.rndis/Label/data

mkdir -p functions/ecm.usb0
echo ${cpsw_4_mac} > functions/ecm.usb0/host_addr
echo ${cpsw_5_mac} > functions/ecm.usb0/dev_addr

mkdir -p functions/acm.usb0

echo "${log} enable USB mass_storage ${usb_image_file}"
mkdir -p functions/mass_storage.usb0
echo ${usb_ms_stall} > functions/mass_storage.usb0/stall
echo ${usb_ms_cdrom} > functions/mass_storage.usb0/lun.0/cdrom
echo ${usb_ms_nofua} > functions/mass_storage.usb0/lun.0/nofua
echo ${usb_ms_removable} > functions/mass_storage.usb0/lun.0/removable
echo ${usb_ms_ro} > functions/mass_storage.usb0/lun.0/ro
echo ${actual_image_file} > functions/mass_storage.usb0/lun.0/file

mkdir -p configs/c.1/strings/0x409
echo "Multifunction with RNDIS" > configs/c.1/strings/0x409/configuration

echo 500 > configs/c.1/MaxPower

ln -s functions/rndis.usb0 configs/c.1/
ln -s functions/ecm.usb0 configs/c.1/

ln -s functions/acm.usb0 configs/c.1/
ln -s functions/mass_storage.usb0 configs/c.1/

echo 48890000.usb > UDC

echo "${log} Starting usb0 network"
cat <<EOF > /etc/udhcpd.usb0.conf
# Managed by $0 - Do not modify unless you know what you are doing!
start      192.168.7.1
end        192.168.7.1
interface  usb0
max_leases 1
option subnet 255.255.255.252
option domain local
option lease 30
EOF
/sbin/ifconfig usb0 192.168.7.2 netmask 255.255.255.252 || true
/usr/sbin/udhcpd /etc/udhcpd.usb0.conf

echo "${log} Starting usb1 network"
cat <<EOF > /etc/udhcpd.usb1.conf
# Managed by $0 - Do not modify unless you know what you are doing!
start      192.168.6.1
end        192.168.6.1
interface  usb0
max_leases 1
option subnet 255.255.255.252
option domain local
option lease 30
EOF
/sbin/ifconfig usb1 192.168.6.2 netmask 255.255.255.252 || true
/usr/sbin/udhcpd /etc/udhcpd.usb1.conf

#Just Cleanup /etc/issue, systemd starts up tty before these are updated...
sed -i -e '/Address/d' /etc/issue || true

check_getty_tty=$(systemctl is-active serial-getty@ttyGS0.service || true)
if [ "x${check_getty_tty}" = "xinactive" ] ; then
	systemctl restart serial-getty@ttyGS0.service || true
fi

