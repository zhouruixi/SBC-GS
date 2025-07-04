#!/bin/bash
# Must using Ubuntu 22.04，24.04 had issue with qemu-aarch64-static
# script running in target debian arm64 OS

set -e
set -x

export LANGUAGE=POSIX
export LC_ALL=POSIX
export LANG=POSIX

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
apt dist-upgrade -y --allow-downgrades
apt install -y git cmake dkms build-essential pkg-config libevent-dev unzip

# Remove old kernel in radxa-zero3_debian_bullseye_xfce_b6.img
dpkg -l | grep -q "linux-image-5.10.160-26-rk356x" && apt purge -y linux-image-5.10.160-26-rk356x linux-headers-5.10.160-26-rk356x

# Generating locales
sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

## 
KVER=$(ls /lib/modules | tail -n 1)
[ -d /root/SourceCode ] || mkdir -p /root/SourceCode
cd /root/SourceCode

# 8812au
git clone -b v5.2.20 --depth=1 https://github.com/svpcom/rtl8812au.git
pushd rtl8812au
sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
./dkms-install.sh
popd

# 8812bu
# make -j16 KSRC=/lib/modules/${KVER}/build
# make install
git clone --depth=1 https://github.com/OpenHD/rtl88x2bu.git
cp -r rtl88x2bu /usr/src/rtl88x2bu-git
sed -i 's/PACKAGE_VERSION="@PKGVER@"/PACKAGE_VERSION="git"/g' /usr/src/rtl88x2bu-git/dkms.conf
dkms add -m rtl88x2bu -v git
dkms build -m rtl88x2bu -v git -k ${KVER}
dkms install -m rtl88x2bu -v git -k ${KVER}

# 8812cu
git clone --depth=1 https://github.com/libc0607/rtl88x2cu-20230728.git
pushd rtl88x2cu-20230728
sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/g' Makefile
sed -i 's/CONFIG_PLATFORM_ARM64_RPI = n/CONFIG_PLATFORM_ARM64_RPI = y/g' Makefile
sed -i 's/CONFIG_RTW_DEBUG = y/CONFIG_RTW_DEBUG = n/g' Makefile
sed -i 's/CONFIG_RTW_MBO = n/CONFIG_RTW_MBO = y/g' Makefile
sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
./dkms-install.sh
popd

# 8812eu
git clone --depth=1 https://github.com/libc0607/rtl88x2eu-20230815.git
pushd rtl88x2eu-20230815
sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/g' Makefile
sed -i 's/CONFIG_PLATFORM_ARM64_RPI = n/CONFIG_PLATFORM_ARM64_RPI = y/g' Makefile
sed -i 's/CONFIG_AP_MODE = n/CONFIG_AP_MODE = y/g' Makefile
sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
./dkms-install.sh
popd

# 8731bu
git clone --depth=1 https://github.com/libc0607/rtl8733bu-20230626.git
pushd rtl8733bu-20230626
sed -i 's/CONFIG_PLATFORM_I386_PC = y/CONFIG_PLATFORM_I386_PC = n/g' Makefile
sed -i 's/CONFIG_PLATFORM_ARM64_RPI = n/CONFIG_PLATFORM_ARM64_RPI = y/g' Makefile
sed -i "s^dkms build -m \${DRV_NAME} -v \${DRV_VERSION}^dkms build -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
sed -i "s^dkms install -m \${DRV_NAME} -v \${DRV_VERSION}^dkms install -m \${DRV_NAME} -v \${DRV_VERSION} -k \$(ls /lib/modules | tail -n 1)^" dkms-install.sh
./dkms-install.sh
popd

# rtw88 downstream for 8814au, 8821au, 8811au, 8821cu, 8811cu, 8723du
git clone --depth=1 https://github.com/lwfinger/rtw88.git
pushd rtw88
make KERNELRELEASE=${KVER}
make KERNELRELEASE=${KVER} install
make KERNELRELEASE=${KVER} install_fw
cat >> /etc/modprobe.d/blacklist-rtw88.conf << EOF
# injection drivers available for 8812au, 8812bu and 8812cu/8822cu
blacklist rtw_8812au
blacklist rtw_8822bu
blacklist rtw_8822cu
EOF
popd

# AR9271
apt install firmware-atheros

# MT7612u

# wfb-ng
git clone -b master --depth=1 https://github.com/svpcom/wfb-ng.git
pushd wfb-ng
./scripts/install_gs.sh wlanx
echo "options rtl88x2cu rtw_tx_pwr_by_rate=0 rtw_tx_pwr_lmt_enable=0" >> /etc/modprobe.d/wfb.conf
echo "options 8733bu rtw_tx_pwr_by_rate=0 rtw_tx_pwr_lmt_enable=0" >> /etc/modprobe.d/wfb.conf
popd

# PixelPilot_rk / fpvue
# From JohnDGodwin
apt -y install librockchip-mpp-dev libdrm-dev libcairo-dev gstreamer1.0-rockchip1 librga-dev librga2 librockchip-mpp1 librockchip-vpu0 libv4l-rkmpp libgl4es libgl4es-dev libspdlog-dev nlohmann-json3-dev libmsgpack-dev libgpiod-dev libyaml-cpp-dev
apt --no-install-recommends -y install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools

git clone --depth=1 https://github.com/OpenIPC/PixelPilot_rk.git
pushd PixelPilot_rk

# Temporarily use pr#62 for test
# git fetch origin pull/62/head:pr-62
# git checkout pr-62

git submodule update --init --recursive
cmake -B build
cmake --build build -j$(nproc) --target install
popd

# Install PixelPilot files
pushd SBC-GS/gs
cp pixelpilot.yaml /etc
cp gsmenu.sh /usr/local/bin
popd

# msposd_rockchip
wget -q https://github.com/OpenIPC/msposd/releases/download/latest/msposd_rockchip -O /usr/local/bin/msposd
chmod +x /usr/local/bin/msposd
wget -q https://raw.githubusercontent.com/OpenIPC/msposd/main/fonts/font_ardu.png -O /usr/share/fonts/font_ardu.png
wget -q https://raw.githubusercontent.com/OpenIPC/msposd/main/fonts/font_ardu_hd.png -O /usr/share/fonts/font_ardu_hd.png
wget -q https://raw.githubusercontent.com/OpenIPC/msposd/main/fonts/font_btfl.png -O /usr/share/fonts/font_btfl.png
wget -q https://raw.githubusercontent.com/OpenIPC/msposd/main/fonts/font_btfl_hd.png -O /usr/share/fonts/font_btfl_hd.png
wget -q https://raw.githubusercontent.com/OpenIPC/msposd/main/fonts/font_inav.png -O /usr/share/fonts/font_inav.png
wget -q https://raw.githubusercontent.com/OpenIPC/msposd/main/fonts/font_inav_hd.png -O /usr/share/fonts/font_inav_hd.png

# wfb-ng-osd
git clone --recursive --depth=1 https://github.com/svpcom/wfb-ng-osd.git
pushd wfb-ng-osd
make osd mode=rockchip
cp -a osd.rockchip /usr/local/bin/wfb-ng-osd
popd

# RubyFPV
rubyfpv_version="11.1"
apt -y install build-essential librockchip-mpp-dev libdrm-dev libcairo-dev libpcap-dev libi2c-dev libgpiod-dev wireless-tools
git clone --depth=1 --branch $rubyfpv_version --single-branch https://github.com/RubyFPV/RubyFPV.git
pushd RubyFPV
make all RUBY_BUILD_ENV=radxa

mkdir -p /home/radxa/ruby/plugins/osd
cp -a ruby_* test_* res version_ruby_base.txt /home/radxa/ruby
cp -a ruby_plugin_* /home/radxa/ruby/plugins/osd
popd

# SBC-GS-CC
pushd SBC-GS/gs
./install.sh
popd

# alink
alink_latest_tag=$(curl -s https://api.github.com/repos/OpenIPC/adaptive-link/tags | jq -r '.[0].name')
wget "https://github.com/OpenIPC/adaptive-link/releases/download/${alink_latest_tag}/alink_gs" -O /usr/local/bin/alink && chmod +x /usr/local/bin/alink
wget "https://raw.githubusercontent.com/OpenIPC/adaptive-link/refs/heads/main/alink_gs.conf" -O /config/alink.conf
ln -s /config/alink.conf /etc/alink.conf

# ttyd
ttyd_version="1.7.7"
wget "https://github.com/tsl0922/ttyd/releases/download/${ttyd_version}/ttyd.aarch64" -O /usr/local/bin/ttyd
chmod +x /usr/local/bin/ttyd
cat > /etc/systemd/system/ttyd.service << EOF
[Unit]
Description=TTYD
After=syslog.target
After=network.target

[Service]
ExecStart=/usr/local/bin/ttyd -t enableZmodem=true -p 81 -W login
Type=simple
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# install useful packages
DEBIAN_FRONTEND=noninteractive apt -y install lrzsz net-tools socat netcat exfatprogs ifstat fbi picocom bridge-utils \
       console-setup psmisc ethtool drm-info libdrm-tests proxychains4 chrony gpsd gpsd-clients tcpdump iptables-persistent \
       dosfstools sshpass fake-hwclock tree evtest python3-dev tftpd-hpa isc-dhcp-client
pip install evdev dotenv

# snander
wget "https://github.com/OpenIPC/snander-mstar/releases/download/latest/snander-linux.zip"
unzip snander-linux.zip snander -d /usr/local/bin
chmod +x /usr/local/bin/snander

# yq
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64 -O /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# yaml-cli
git clone --depth=1 https://github.com/OpenIPC/yaml-cli.git
pushd yaml-cli
cmake .
make -j$(nproc)
make install
popd

# disable services
sed -i '/disable_service systemd-networkd/a disable_service dnsmasq' /config/before.txt
# systemctl disable tftpd-hpa
update-rc.d -f tftpd-hpa remove

# enable services
sed -i "s/disable_service systemd-networkd/# disable_service systemd-networkd/" /config/before.txt
sed -i "s/disable_service ssh/# disable_service ssh/" /config/before.txt
sed -i "s/disable_service nmbd/# disable_service nmbd/" /config/before.txt
sed -i "s/disable_service smbd/# disable_service smbd/" /config/before.txt

# disable auto extend root partition and rootfs
apt purge -y cloud-initramfs-growroot
sed -i "s/resize_root/# resize_root/" /config/before.txt

# umanage NICs from NetwrkManager
cat > /etc/NetworkManager/conf.d/00-gs-unmanaged.conf << EOF
[keyfile]
unmanaged-devices=interface-name:eth0;unmanaged-devices=interface-name:eth1;interface-name:br0;interface-name:usb0;interface-name:dummy0;interface-name:radxa0;interface-name:wlx*
EOF

# set root password to root
echo "root:root" | chpasswd
# permit root login over ssh
sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
# sync mount /config
sed -i 's/\(UUID=\S*\s*\/config\s*vfat\s*defaults,x-systemd.automount\)/\1,sync/' /etc/fstab
# set gpsd not listen on ipv6
sed -i "/ListenStream=\[::1\]:2947/s/^/# /" /lib/systemd/system/gpsd.socket
# set chrony use gps time
echo "refclock SHM 0 refid GPS offset 0.1 delay 0.1" >> /etc/chrony/chrony.conf
# change tftp root to /gs/webui/firmware
sed -i 's|TFTP_DIRECTORY="/srv/tftp"|TFTP_DIRECTORY="/gs/webui/firmware"|' /etc/default/tftpd-hpa

# enable color support of ls and also add handy aliases
cat >> /etc/bash.bashrc << EOF
# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

# Enable ipv4 forward
grep -q "^net\.ipv4\.ip_forward.*1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Forward SBC port 2222/8080 to IPC port 22/80
cat > /etc/iptables/rules.v4 << EOF
*nat
-A PREROUTING -p tcp -m tcp --dport 2222 -j DNAT --to-destination 10.5.0.10:22
-A PREROUTING -p tcp -m tcp --dport 8080 -j DNAT --to-destination 10.5.0.10:80
-A POSTROUTING -p tcp -m tcp ! -s 10.5.0.0/24 -d 10.5.0.10 --dport 22 -j SNAT --to-source 10.5.0.1
-A POSTROUTING -p tcp -m tcp ! -s 10.5.0.0/24 -d 10.5.0.10 --dport 80 -j SNAT --to-source 10.5.0.1
COMMIT
EOF

# Save fake hwclock to disk every minute
cat >> /etc/systemd/system/save-fakehwclock.timer << EOF
[Unit]
Description=Save fake hwclock to disk every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=save-fakehwclock.service

[Install]
WantedBy=timers.target
EOF

cat >> /etc/systemd/system/save-fakehwclock.service << EOF
[Unit]
Description=Save fake hwclock to disk

[Service]
Type=oneshot
ExecStart=/sbin/fake-hwclock save
EOF

systemctl enable save-fakehwclock.timer
echo $(date "+%Y-%m-%d %H:%M:%S") > /etc/fake-hwclock.data


rm -rf /root/SourceCode
rm /etc/resolv.conf
chown -R 1000:1000 /gs

exit 0
