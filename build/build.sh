#!/bin/bash
# Must using Ubuntu 22.04，24.04 had issue with qemu-aarch64-static
# script running in target debian arm64 OS

# From EgorNiKO: the script has a problem with missing packages when running on Ubuntu images

set -e
set -x

export LANGUAGE=POSIX
export LC_ALL=POSIX
export LANG=POSIX

BOARD=$(cat /etc/hostname)
echo "BORAD: $BOARD"

# add dns server
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Remove unnecessary package for xface base image [ need remove more unnecessary package ]
if dpkg -l | grep -q xface4; then
	apt purge -y xfce4* lightdm* liblightdm-gobject-1-0 libupower-glib3 libxklavier16 upower chromium-x11 xserver-xorg-core xserver-xorg-legacy rockchip-chromium-x11-utils firefox-esr x11-apps
	# fix radxa-sddm-theme uninstall issue
	mkdir -p /usr/share/sddm/themes/breeze
	touch /usr/share/sddm/themes/breeze/Main.qml
	# fix radxa-system-config-rockchip uninstall issue
	[ -f /etc/modprobe.d/panfrost.conf.bak ] && rm /etc/modprobe.d/panfrost.conf.bak
	apt autoremove -y --purge
fi

# Update system to date
apt update
DEBIAN_FRONTEND=noninteractive apt dist-upgrade -y --allow-downgrades
apt install -y git cmake dkms build-essential meson

## 
[ -d /home/radxa/SourceCode ] || mkdir -p /home/radxa/SourceCode
cd /home/radxa/SourceCode

# Installing/Remove the required package depending on the board
case $BOARD in
	radxa-zero3)
		# Remove old kernel in radxa-zero3_debian_bullseye_xfce_b6.img
		dpkg -l | grep -q "linux-image-5.10.160-26-rk356x" && apt purge -y linux-image-5.10.160-26-rk356x linux-headers-5.10.160-26-rk356x
	;;
	orangepi3b)
		if [ -z $(dpkg -l | grep 'linux-headers-legacy-rockchip-rk356x') ];then
			dpkg -i /opt/linux-headers-legacy-rockchip-rk356x_1.0.6_arm64.deb
		fi
	;;
esac

# 8812au
# The check is needed to speed up the process of creating a new image without updating drivers
DRIVE_NAME="88XXau_wfb"
if [ $(find /lib/modules -name ${DRIVE_NAME}* |  wc -l) == 0 ];then
	git clone -b v5.2.20 --depth=1 https://github.com/svpcom/rtl8812au.git
	pushd rtl8812au
	sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
	sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
	./dkms-install.sh
	popd
else 
	echo "${DRIVE_NAME} is already installed"
fi

# 8812bu
# make -j16 KSRC=/lib/modules/$(ls /lib/modules | tail -n 1)/build
# make install
DRIVE_NAME="88x2bu"
if [ $(find /lib/modules -name ${DRIVE_NAME}* |  wc -l) == 0 ];then
	git clone --depth=1 https://github.com/OpenHD/rtl88x2bu.git
	cp -r rtl88x2bu /usr/src/rtl88x2bu-git
	sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="git"/g' /usr/src/rtl88x2bu-git/dkms.conf
	dkms add -m rtl88x2bu -v git
	dkms build -m rtl88x2bu -v git -k $(ls /lib/modules | tail -n 1)
	dkms install -m rtl88x2bu -v git -k $(ls /lib/modules | tail -n 1)
else 
	echo "${DRIVE_NAME} is already installed"
fi

# 8812cu
DRIVE_NAME="88x2cu"
if [ $(find /lib/modules -name ${DRIVE_NAME}* |  wc -l) == 0 ];then
	git clone --depth=1 https://github.com/libc0607/rtl88x2cu-20230728.git
	pushd rtl88x2cu-20230728
	sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/g' Makefile
	sed -i 's/CONFIG_PLATFORM_ARM64_RPI = n/CONFIG_PLATFORM_ARM64_RPI = y/g' Makefile
	sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
	sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
	popd
else 
	echo "${DRIVE_NAME} is already installed"
fi

# 8812eu
DRIVE_NAME="8812eu"
if [ $(find /lib/modules -name ${DRIVE_NAME}* |  wc -l) == 0 ];then
	git clone --depth=1 https://github.com/libc0607/rtl88x2eu-20230815.git
	pushd rtl88x2eu-20230815
	sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/g' Makefile
	sed -i 's/CONFIG_PLATFORM_ARM64_RPI = n/CONFIG_PLATFORM_ARM64_RPI = y/g' Makefile
	sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
	sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
	./dkms-install.sh
	popd
else 
	echo "${DRIVE_NAME} is already installed"
fi

# 8731bu
DRIVE_NAME="8733bu"
if [ $(find /lib/modules -name ${DRIVE_NAME}* |  wc -l) == 0 ];then
	git clone --depth=1 https://github.com/libc0607/rtl8733bu-20230626.git
	pushd rtl8733bu-20230626
	sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/g' Makefile
	sed -i 's/CONFIG_PLATFORM_ARM64_RPI = n/CONFIG_PLATFORM_ARM64_RPI = y/g' Makefile
	sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
	sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
	popd
else 
	echo "${DRIVE_NAME} is already installed"
fi

# 8814au
DRIVE_NAME="8814au"
if [ $(find /lib/modules -name ${DRIVE_NAME}* |  wc -l) == 0 ];then
	git clone --depth=1 https://github.com/morrownr/8814au.git rtl8814au
	DRV_NAME_8814AU="rtl8814au"
	DRV_VERSION_8814AU="5.8.5.1"
	sed -i "/MODULE_VERSION(DRIVERVERSION);/a MODULE_IMPORT_NS(VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver);" rtl8814au/os_dep/linux/os_intfs.c
	sed -i "s^kernelver=\$kernelver ./dkms-make.sh^'make' -j\$(nproc) KVER=\${kernelver} KSRC=/lib/modules/\${kernelver}/build^" rtl8814au/dkms.conf
	cp -rf rtl8814au /usr/src/${DRV_NAME_8814AU}-${DRV_VERSION_8814AU}
	dkms add -m ${DRV_NAME_8814AU} -v ${DRV_VERSION_8814AU}
	dkms build -m ${DRV_NAME_8814AU} -v ${DRV_VERSION_8814AU} -k $(ls /lib/modules | tail -n 1)
	dkms install -m ${DRV_NAME_8814AU} -v ${DRV_VERSION_8814AU} -k $(ls /lib/modules | tail -n 1)
else 
	echo "${DRIVE_NAME} is already installed"
fi

# AR9271
DRIVE_NAME="atk9"
if [ $(find /lib -name ${DRIVE_NAME}* |  wc -l) == 0 ];then
	if $(apt-cache search firmware-atheros | grep -q "firmware-atheros"); then
		apt install -y firmware-atheros
	else
		git clone --depth=1 -b master --single-branch https://github.com/qca/open-ath9k-htc-firmware.git ${DRIVE_NAME}
		pushd ${DRIVE_NAME}
		make toolchain
		make -C target_firmware
		cp -f target_firmware/*.fw /lib/firmware/
		popd
	fi
else 
	echo "${DRIVE_NAME} is already installed"
fi

# MT7612u

# wfb-ng
git clone -b master --depth=1 --single-branch https://github.com/svpcom/wfb-ng.git
pushd wfb-ng
./scripts/install_gs.sh wlanx
popd

# PixelPilot_rk / fpvue
apt install -y libcairo-dev libdrm-dev 
apt --no-install-recommends -y install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools 

case $BOARD in
	radxa-zero3)
		apt install -y libgl4es libgl4es-dev librga2 librga-dev librockchip-mpp1 librockchip-mpp-dev librockchip-vpu0 libv4l-rkmpp gstreamer1.0-rockchip1
	;;
	orangepi3b)
		# Installing dependencies
		git clone --depth 1 --single-branch https://github.com/rockchip-linux/mpp.git
		pushd mpp
		cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib
		cmake --build build --target install -j$(($(grep -c "^processor" /proc/cpuinfo) - 1))
		popd
		 
		git clone --depth 1 --single-branch https://github.com/tsukumijima/librga-rockchip.git
		pushd librga-rockchip
		meson builddir --prefix=/usr --libdir=lib
		ninja -C builddir install
		popd
		
		# Installing gstreamer plugins mpp for Rockchip
		git clone --depth 1 -b gstreamer-rockchip --single-branch https://github.com/JeffyCN/rockchip_mirrors.git
		pushd rockchip_mirrors
		meson builddir --prefix=/usr --libdir=lib/aarch64-linux-gnu
		ninja -C builddir install
		popd
	;;
esac

git clone --depth=1 https://github.com/OpenIPC/PixelPilot_rk.git 
pushd PixelPilot_rk
cmake -B build
cmake --build build --target install
popd

# SBC-GS-CC
pushd SBC-GS/gs
./install.sh
popd

# install useful packages
DEBIAN_FRONTEND=noninteractive apt -y install lrzsz net-tools socat netcat exfatprogs ifstat fbi minicom bridge-utils console-setup psmisc ethtool drm-info libdrm-tests proxychains4

# disable services
case $BOARD in
	radxa-zero3)
		# enable services
		sed -i "s/disable_service ssh/# disable_service ssh/" /config/before.txt
		sed -i "s/disable_service nmbd/# disable_service smbd/" /config/before.txt
		sed -i "s/disable_service smbd/# disable_service nmbd/" /config/before.txt

		# disable auto extend root partition and rootfs
		apt purge -y cloud-initramfs-growroot
		sed -i "s/resize_root/# resize_root/" /config/before.txt

		# disable services
		sed -i '/disable_service systemd-networkd/a disable_service dnsmasq' /config/before.txt
	;;
	orangepi3b)
		# Added for compatibility with RadxaZero3
		echo "" > /config/before.txt
	;;
esac

rm -rf /home/radxa/SourceCode
rm /etc/resolv.conf
chown -R 1000:1000 /home/radxa

exit 0
