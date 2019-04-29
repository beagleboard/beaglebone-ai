#!/bin/sh -e
#

DIR=$PWD
TEMPDIR=$(mktemp -d)

ARCH=$(uname -m)
SYST=$(uname -n)

if [ "x${ARCH}" = "xi686" ] ; then
	echo "Linaro no longer supports 32bit cross compilers, thus 32bit is no longer suppored by this script..."
	exit
fi

# Number of jobs for make to run in parallel.
CORES=$(getconf _NPROCESSORS_ONLN)

. ./version.sh

git="git am"

mkdir -p ${DIR}/git/
mkdir -p ${DIR}/dl/
mkdir -p ${DIR}/deploy/

rm -rf ${DIR}/deploy/latest-bootloader.log || true

#export MIRROR="http://example.com"
#./build.sh
if [ ! "${MIRROR}" ] ; then
	MIRROR="http:"
fi

if [ -d $HOME/dl/gcc/ ] ; then
	gcc_dir="$HOME/dl/gcc"
else
	gcc_dir="${DIR}/dl"
fi

wget_dl="wget -c --directory-prefix=${gcc_dir}/"

dl_gcc_generic () {
	site="https://releases.linaro.org"
	archive_site="https://releases.linaro.org/archive"
	non_https_site="http://releases.linaro.org"
	non_https_archive_site="http://releases.linaro.org/archive"
	WGET="wget -c --directory-prefix=${gcc_dir}/"
	if [ ! -f "${gcc_dir}/${directory}/${datestamp}" ] ; then
		echo "Installing: ${toolchain_name}"
		echo "-----------------------------"
		${WGET} "${site}/${version}/${filename}" || ${WGET} "${archive_site}/${version}/${filename}" || ${WGET} "${non_https_site}/${version}/${filename}" || ${WGET} "${non_https_archive_site}/${version}/${filename}"
		if [ -d "${gcc_dir}/${directory}" ] ; then
			rm -rf "${gcc_dir}/${directory}" || true
		fi
		tar -xf "${gcc_dir}/${filename}" -C "${gcc_dir}/"
		if [ -f "${gcc_dir}/${directory}/${binary}gcc" ] ; then
			touch "${gcc_dir}/${directory}/${datestamp}"
		fi
	fi

	if [ "x${ARCH}" = "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		if [ -f /usr/bin/ccache ] ; then
			CC="ccache ${gcc_dir}/${directory}/${binary}"
		else
			CC="${gcc_dir}/${directory}/${binary}"
		fi
	fi
}

gcc_linaro_gnueabihf_6 () {
		#
		#https://releases.linaro.org/components/toolchain/binaries/6.2-2016.11/arm-linux-gnueabihf/gcc-linaro-6.2.1-2016.11-x86_64_arm-linux-gnueabihf.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/6.4-2017.08/arm-linux-gnueabihf/gcc-linaro-6.4.1-2017.08-x86_64_arm-linux-gnueabihf.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/6.4-2017.11/arm-linux-gnueabihf/gcc-linaro-6.4.1-2017.11-x86_64_arm-linux-gnueabihf.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/6.4-2018.05/arm-linux-gnueabihf/gcc-linaro-6.4.1-2018.05-x86_64_arm-linux-gnueabihf.tar.xz
		#https://releases.linaro.org/components/toolchain/binaries/6.5-2018.12/arm-linux-gnueabihf/gcc-linaro-6.5.0-2018.12-x86_64_arm-linux-gnueabihf.tar.xz
		#

		gcc_version="6.5"
		gcc_minor=".0"
		release="18.12"
		target="arm-linux-gnueabihf"

		version="components/toolchain/binaries/${gcc_version}-20${release}/${target}"
		filename="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}.tar.xz"
		directory="gcc-linaro-${gcc_version}${gcc_minor}-20${release}-x86_64_${target}"

		datestamp="${gcc_version}-20${release}-${target}"

		binary="bin/${target}-"

	dl_gcc_generic
}

git_generic () {
	echo "Starting ${project} build for: ${board}"
	echo "-----------------------------"

	if [ ! -f ${DIR}/git/${project}/.git/config ] ; then
		git clone git://github.com/RobertCNelson/${project}.git ${DIR}/git/${project}/
	fi

	cd ${DIR}/git/${project}/
	git pull --no-edit || true
	git fetch --tags || true
	cd -

	if [ -d ${DIR}/scratch/${project} ] ; then
		rm -rf ${DIR}/scratch/${project} || true
	fi

	mkdir -p ${DIR}/scratch/${project}
	git clone --shared ${DIR}/git/${project} ${DIR}/scratch/${project}

	cd ${DIR}/scratch/${project}

	if [ "${GIT_SHA}" ] ; then
		echo "Checking out: ${GIT_SHA}"
		git checkout ${GIT_SHA} -b ${project}-scratch
	fi
}

git_cleanup () {
	cd ${DIR}/

	rm -rf ${DIR}/scratch/u-boot || true

	echo "${project} build completed for: ${board}"
	echo "-----------------------------"
}

git_cleanup_save () {
	cd ${DIR}/

	echo "${project} build completed for: ${board}"
	echo "-----------------------------"
}

halt_patching_uboot () {
	pwd
	exit
}

file_save () {
	cp -v ./${filename_search} ${DIR}/${filename_id}
}

build_u_boot () {
	project="u-boot"
	git_generic
	RELEASE_VER="-r0"

	make ARCH=arm CROSS_COMPILE="${CC}" distclean
	UGIT_VERSION=$(git describe)

	echo "-----------------------------"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" distclean"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${uboot_config}"
	echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${BUILDTARGET}"
	echo "-----------------------------"

	#v2019.04-rc4
	p_dir="${DIR}/patches/${uboot_stable}"
	if [ "${stable}" ] ; then
		#r1: initial release
		#r2: (pending)
		RELEASE_VER="-r1" #bump on every change...
		#halt_patching_uboot

		case "${board}" in
		am57xx_evm)
			echo "patch -p1 < \"${p_dir}/0001-am57xx_evm-fixes.patch\""
			#halt_patching_uboot
			patch -p1 < "${p_dir}/0001-am57xx_evm-fixes.patch"
			#halt_patching_uboot
			cp "${p_dir}/am5729-beagleboneai.dts" arch/arm/dts/am5729-beagleboneai.dts
			# meld Makefile  /opt/github/u-boot/arch/arm/dts/Makefile
			cp "${p_dir}/Makefile" arch/arm/dts/Makefile
			# meld board.c  /opt/github/u-boot/board/ti/am57xx/board.c
			cp "${p_dir}/board.c" board/ti/am57xx/board.c
			# meld mux_data.h  /opt/github/u-boot/board/ti/am57xx/mux_data.h
			cp "${p_dir}/mux_data.h" board/ti/am57xx/mux_data.h
			# meld am57xx_evm_defconfig  /opt/github/u-boot/configs/am57xx_evm_defconfig
			cp "${p_dir}/am57xx_evm_defconfig" configs/am57xx_evm_defconfig
			# meld am57xx_evm.h  /opt/github/u-boot/include/configs/am57xx_evm.h
			cp "${p_dir}/am57xx_evm.h" include/configs/am57xx_evm.h
			# meld hw_data.c  /opt/github/u-boot/arch/arm/mach-omap2/omap5/hw_data.c
			cp "${p_dir}/hw_data.c" arch/arm/mach-omap2/omap5/hw_data.c
			# meld patches/v2019.04-rc4/boot.h scratch/u-boot/include/environment/ti/boot.h
			cp "${p_dir}/boot.h" include/environment/ti/boot.h

			git add arch/arm/dts/am5729-beagleboneai.dts
			git commit -a -m 'BeagleBone AI support'
			git format-patch -1 -o ../../patches/
			#git format-patch -1 -o ../../../buildroot/local/board/beagleboneai/patches/uboot/
			#halt_patching_uboot
			;;
		esac
	fi

	if [ "x${board}" = "xam57xx_evm_em" ] ; then
		if [ "x${GIT_SHA}" = "xv2017.01" ] ; then
			git pull --no-edit git://git.ti.com/ti-u-boot/ti-u-boot.git ti-u-boot-2017.01
			git checkout 9fd60700db4562ffac00317a9a44761b8c3255f1 -b tmp

			p_dir="${DIR}/patches/ti2017.01"
			echo "patch -p1 < \"${p_dir}/0001-EM-TF-EVK-AM5728-u-boot.patch\""
			echo "patch -p1 < \"${p_dir}/0002-embest-diff.patch\""
			echo "patch -p1 < \"${p_dir}/0003-embest-Add-begal-ai-support-baed-on-EVK_AM5728-board.patch\""
			echo "patch -p1 < \"${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch\""
			echo "patch -p1 < \"${p_dir}/wip.diff\""
			${git} "${p_dir}/0001-EM-TF-EVK-AM5728-u-boot.patch"
			${git} "${p_dir}/0002-embest-diff.patch"
			${git} "${p_dir}/0003-embest-Add-begal-ai-support-baed-on-EVK_AM5728-board.patch"
			${git} "${p_dir}/0001-beagle_x15-uEnv.txt-bootz-n-fixes.patch"
			#halt_patching_uboot
			patch -p1 < ${p_dir}/wip.diff
		fi
	fi

	if [ -f "${DIR}/stop.after.patch" ] ; then
		echo "-----------------------------"
		pwd
		echo "-----------------------------"
		echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${uboot_config}"
		echo "make ARCH=arm CROSS_COMPILE=\"${CC}\" ${BUILDTARGET}"
		echo "-----------------------------"
		exit
	fi

	uboot_filename="${board}-${UGIT_VERSION}${RELEASE_VER}"

	mkdir -p ${DIR}/deploy/${board}

	make ARCH=arm CROSS_COMPILE="${CC}" ${uboot_config} > /dev/null
	echo "Building ${project}: ${uboot_filename}:"
	#make ARCH=arm CROSS_COMPILE="${CC}" menuconfig
	make ARCH=arm CROSS_COMPILE="${CC}" -j${CORES} ${BUILDTARGET} > /dev/null

	unset UBOOT_DONE
	echo "-----------------------------"
	#SPL based targets, need MLO and u-boot.img from u-boot
	if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/scratch/${project}/MLO ] ; then
		filename_search="MLO"
		filename_id="deploy/${board}/MLO-${uboot_filename}"
		file_save

		if [ -f ${DIR}/scratch/${project}/u-boot-dtb.img ] ; then
			filename_search="u-boot-dtb.img"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		elif [ -f ${DIR}/scratch/${project}/u-boot.img ] ; then
			filename_search="u-boot.img"
			filename_id="deploy/${board}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi
	fi
	echo "-----------------------------"

	git_cleanup_save
}

cleanup () {
	unset GIT_SHA
	unset transitioned_to_testing
	unset uboot_config
	build_old="false"
	build_stable="false"
	build_testing="false"
}

build_uboot_stable () {
	if [ "x${build_stable}" = "xtrue" ] ; then
		stable=1
		if [ "${uboot_stable}" ] ; then
			GIT_SHA=${uboot_stable}
			build_u_boot
		fi
		unset stable
		build_stable="false"
	fi
}

build_uboot_gnueabihf () {
	if [ "x${uboot_config}" = "x" ] ; then
		uboot_config="${board}_defconfig"
	fi
	gcc_linaro_gnueabihf_6
	build_uboot_stable
}

am57xx_evm_mainline () {
	cleanup
	build_stable="true"
	board="am57xx_evm" ; build_uboot_gnueabihf
}

am57xx_evm_em () {
	cleanup

	board="am57xx_evm_em"
	uboot_config="som_am572x_defconfig"
	gcc_linaro_gnueabihf_6
	GIT_SHA="v2017.01"
	build_u_boot
}
#exit

am57xx_evm_em
am57xx_evm_mainline

#
