#!/bin/bash

set -e
set -x
source /etc/gs.conf
[ "$gs_enable" == 'no' ] && exit 0

sleep 12
setfont /usr/share/consolefonts/CyrAsia-TerminusBold32x16.psf.gz
cat | tee /dev/ttyFIQ0 /dev/tty1 << EOF

############################### Welcome to SBC Ground Station ##################################
#                                                                                              #
# WARING: Thist is init startup, may take few minuts, system will auto restart when init done. #
# WARING: Do not turn off the power during the initialization process.                         #
#                                                                                              #
################################################################################################

EOF

BOARD=$(cat /etc/hostname)

# Expand overlay partition size and create vides partition(exfat)
[ -d $rec_dir ] || mkdir -p $rec_dir
os_dev=$(blkid | grep rootfs | grep -oP "/dev/.+(?=p\d+)") || true
if [ ! -b ${os_dev}p5 ]; then
	sgdisk -ge $os_dev
	overlay_partition_start=$(parted -m $os_dev unit MiB print | tail -n 1 | cut -d: -f3 | tr -d 'MiB')
	overlay_partition_end=$(( $overlay_partition_start + $rootfs_reserved_space ))
	cat << EOF | parted ---pretend-input-tty $os_dev > /dev/null 2>&1
resizepart 4 ${overlay_partition_end}MiB
yes
EOF
	resize2fs ${os_dev}p4
	videos_partition_start=$(parted -m $os_dev unit MiB print | tail -n 1 | cut -d: -f3 | tr -d 'MiB')
	parted -s $os_dev mkpart videos fat32 ${videos_partition_start}MiB 100%
	mkfs.exfat -L videos ${os_dev}p5
fi

# mount overlay lower to rw on init boot
mount -o remount,rw /media/root-ro

# mount /dev/disk/by-partlabel/videos $rec_dir
if ! grep -Pq "^/dev/[^\s]*\s*${rec_dir}\s*exfat\s*defaults\,nofail\s*0\s*0" /media/root-ro/etc/fstab; then
	echo -e "${os_dev}p5 ${rec_dir} exfat defaults,nofail 0 0" >> /media/root-ro/etc/fstab
fi

# Enable dtbo
# set max resolution to 4k, disabled by default
dtc -I dts -O dtb -o /media/root-ro/boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo.disabled /gs/rk3566-hdmi-max-resolution-4k.dts
# enbale USB OTG role switch
dtc -I dts -O dtb -o /media/root-ro/boot/dtbo/rk3566-dwc3-otg-role-switch.dtbo /gs/rk3566-dwc3-otg-role-switch.dts
# INA226 device, disabled by default
dtc -I dts -O dtb -o /media/root-ro/boot/dtbo/rk3566-ina226-overlay.dtbo.disabled /gs/rk3566-ina226-overlay.dts


# Add br0 network configuration
[ -f /etc/systemd/network/br0.netdev ] || cat > /etc/systemd/network/br0.netdev << EOF
[NetDev]
Name=br0
Kind=bridge
EOF

[ -f /etc/systemd/network/br0.network ] || cat > /etc/systemd/network/br0.network << EOF
[Match]
Name=br0

[Network]
Address=${br0_fixed_ip}
Address=${br0_fixed_ip2}
DHCP=yes
EOF

[ -f /etc/systemd/network/eth0.network ] || cat > /etc/systemd/network/eth0.network << EOF
[Match]
Name=eth0

[Network]
Bridge=br0
EOF

[ -f /etc/systemd/network/eth1.network ] || cat > /etc/systemd/network/eth1.network << EOF
[Match]
Name=eth1

[Network]
Bridge=br0
EOF

[ -f /etc/systemd/network/usb0.network ] || cat > /etc/systemd/network/usb0.network << EOF
[Match]
Name=usb0

[Network]
Bridge=br0
EOF

[ -f /etc/systemd/network/dummy0.netdev ] || cat > /etc/systemd/network/dummy0.netdev << EOF
[NetDev]
Name=dummy0
Kind=dummy
EOF

[ -f /etc/systemd/network/dummy0.network ] || cat > /etc/systemd/network/dummy0.network << EOF
[Match]
Name=dummy0

[Network]
Bridge=br0
EOF

# Add radxa0 usb gadget network configuration
echo "start configure radxa0 usb gadget network"
gadget_net_fixed_ip_addr=${gadget_net_fixed_ip%/*}
gadget_net_fixed_ip_sub=${gadget_net_fixed_ip%.*}
if [ ! -f /etc/network/interfaces.d/radxa0 ]; then
        cat > /etc/network/interfaces.d/radxa0 << EOF
auto radxa0
allow-hotplug radxa0
iface radxa0 inet static
        address $gadget_net_fixed_ip
        # post-up mount -o remount,ro /Videos && link mass
        # post-down remove mass && mount -o remount,rw /Videos
        up /usr/sbin/dnsmasq --conf-file=/dev/null --no-hosts --bind-interfaces --except-interface=lo --clear-on-reload --strict-order --listen-address=${gadget_net_fixed_ip_addr} --dhcp-range=${gadget_net_fixed_ip_sub}.21,${gadget_net_fixed_ip_sub}.199,12h --dhcp-lease-max=5 --pid-file=/run/dnsmasq-radxa0.pid --dhcp-option=3 --dhcp-option=6
EOF
fi

# Add samba configuration
grep -q "\[config\]" /etc/samba/smb.conf || cat >> /etc/samba/smb.conf << EOF
[Videos]
   path = /Videos
   writable = yes
   browseable = yes
   create mode = 0777
   directory mode = 0777
   guest ok = yes
   force user = root

[config]
   path = /config
   writable = yes
   browseable = yes
   create mode = 0777
   directory mode = 0777
   guest ok = yes
   force user = root
EOF

# wfb default configuration
cat > /etc/wifibroadcast.cfg << EOF
[common]
wifi_channel = '${wfb_channel}'
wifi_region = '${wfb_region}'

[gs_mavlink]
peer = 'connect://${wfb_outgoing_ip}:${wfb_outgoing_port_mavlink}'

[gs_video]
peer = 'connect://${wfb_outgoing_ip}:${wfb_outgoing_port_video}'

[cluster]

nodes = {
          '127.0.0.1': { 'wlans': ['wlan'], 'wifi_txpower': None, 'server_address': '127.0.0.1' },
          # Remote cards:
          #'192.168.1.123' : { 'wlans': ['wlan0', 'wlan1'], 'wifi_txpower': 'off'},    # rx-only node
          #'192.168.1.155' : { 'wlans': ['wlan0', 'wlan1']},     # rx/tx node
        }

server_address = '${br0_fixed_ip%/*}'

EOF

# gpsd and chrony configuration
cat > /etc/default/gpsd << EOF
stty -F /dev/${gps_uart} ${gps_uart_baudrate}
START_DAEMON="true"
DEVICES="/dev/${gps_uart}"
GPSD_OPTIONS="-n -b -G -r"
USBAUTO="true"
EOF

systemctl disable gs-init.service

# check and apply configuration in gs.conf
source /gs/gs-applyconf.sh

while [ -f /config/before.txt ]; do sleep 2; done
sync
reboot
