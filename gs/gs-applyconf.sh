#!/bin/bash

set -e
set -x

need_u_boot_update=0
need_reboot=0
need_restart_services=""

## kernel cmdline configuration
[ -f /etc/kernel/cmdline.bak ] || cp /etc/kernel/cmdline /etc/kernel/cmdline.bak
kernel_cmdline_now=$(< /etc/kernel/cmdline)
kernel_cmdline_base=$(< /etc/kernel/cmdline.bak)
kernel_cmdline_config=$kernel_cmdline_base
# append kernel cmdline
[ -n "$append_kernel_cmdline" ] && kernel_cmdline_config="$kernel_cmdline_config $append_kernel_cmdline"
# system wide screen mode
if [ "$system_wide_screen_mode" == "yes" ]; then
	[ -n "$screen_mode" ] && kernel_cmdline_config="$kernel_cmdline_config video=HDMI-A-1:${screen_mode}"
fi
# update kernel cmdline
if [ "$kernel_cmdline_config" != "$kernel_cmdline_now" ]; then
	echo "$kernel_cmdline_config" > /etc/kernel/cmdline
	need_u_boot_update=1
	need_reboot=1
fi

## dtbo configuration
# set max resolution to 4k
if [[ "$max_resolution_4k" == "yes" && -f /boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo.disabled ]]; then
        mv /boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo.disabled /boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo
        need_u_boot_update=1
        need_reboot=1
elif [[ "$max_resolution_4k" == "no" && -f /boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo ]]; then
        mv /boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo /boot/dtbo/rk3566-hdmi-max-resolution-4k.dtbo.disabled
        need_u_boot_update=1
        need_reboot=1
fi
# disable integrated wifi of radxa zero 3W
if [[ "$disable_integrated_wifi" == "yes" && -f /boot/dtbo/radxa-zero3-disabled-wireless.dtbo.disabled ]]; then
	mv /boot/dtbo/radxa-zero3-disabled-wireless.dtbo.disabled /boot/dtbo/radxa-zero3-disabled-wireless.dtbo
	need_u_boot_update=1
	need_reboot=1
elif [[ "$disable_integrated_wifi" == "no" && -f /boot/dtbo/radxa-zero3-disabled-wireless.dtbo ]]; then
	mv /boot/dtbo/radxa-zero3-disabled-wireless.dtbo /boot/dtbo/radxa-zero3-disabled-wireless.dtbo.disabled
	need_u_boot_update=1
	need_reboot=1

fi
# enable external antenna of radxa zero 3W
if [[ "$enable_external_antenna" == "yes" && -f /boot/dtbo/radxa-zero3-external-antenna.dtbo.disabled && -d /sys/class/net/wlan0 ]]; then
	mv /boot/dtbo/radxa-zero3-external-antenna.dtbo.disabled /boot/dtbo/radxa-zero3-external-antenna.dtbo
	need_u_boot_update=1
	need_reboot=1
elif [[ "$enable_external_antenna" == "no" && -f /boot/dtbo/radxa-zero3-external-antenna.dtbo && -d /sys/class/net/wlan0 ]] ; then
	mv /boot/dtbo/radxa-zero3-external-antenna.dtbo /boot/dtbo/radxa-zero3-external-antenna.dtbo.disabled
	need_u_boot_update=1
	need_reboot=1
fi
# dtbo enable or disable
dtbo_enable_array=$(echo $dtbo_enable_list | tr -s ' ' | tr ' ' '\n' | sort)
dtbo_enabled_array=$(ls /boot/dtbo/rk3568-*.dtbo 2>/dev/null | sed -e "s^/boot/dtbo/rk3568-^^g" -e "s/.dtbo//g" | sort)
dtbo_need_enable=$(comm -23 <(echo "$dtbo_enable_array") <(echo "$dtbo_enabled_array"))
dtbo_need_disable=$(comm -13 <(echo "$dtbo_enable_array") <(echo "$dtbo_enabled_array"))
# enable dtbo
if [ -n "$dtbo_need_enable" ]; then
	for dtboe in $dtbo_need_enable; do
		if [ -f /boot/dtbo/rk3568-${dtboe}.dtbo.disabled ]; then
			mv /boot/dtbo/rk3568-${dtboe}.dtbo.disabled /boot/dtbo/rk3568-${dtboe}.dtbo
			need_u_boot_update=1
			need_reboot=1
		fi
	done
fi
# disable dtbo
if [ -n "$dtbo_need_disable" ]; then
	for dtbod in $dtbo_need_disable; do
		mv /boot/dtbo/rk3568-${dtbod}.dtbo /boot/dtbo/rk3568-${dtbod}.dtbo.disabled
	done
	need_u_boot_update=1
	need_reboot=1
fi

## Update REC_Dir in fstab
[ -d $REC_Dir ] || mkdir -p $REC_Dir
if [ "${REC_Dir}" != "$(grep -oP '(?<=^/dev/mmcblk1p4\t).*?(?=\t)' /etc/fstab)" ]; then
	sed -i "s#^\(/dev/mmcblk1p4\t\)[^\t]*#\1${REC_Dir}#" /etc/fstab
	need_reboot=1
fi

## GPS configuration
if [[ $(grep -q "stty -F /dev/${gps_uart} ${gps_uart_baudrate}" /etc/default/gpsd) && $(grep -q "DEVICES=\"/dev/${gps_uart}\"" /etc/default/gpsd) ]]; then
	echo "GPS configuration not changed!"
else
	cat > /etc/default/gpsd << EOF
stty -F /dev/${gps_uart} ${gps_uart_baudrate}
START_DAEMON="true"
DEVICES="/dev/${gps_uart}"
GPSD_OPTIONS="-n -b -G -r"
USBAUTO="true"
EOF
fi

## Network configuration
# br0 configuration
if [[ -f /etc/systemd/network/br0.network && -n "$br0_fixed_ip" && -n "$br0_fixed_ip2" ]]; then
        br0_fixed_ip_OS=$(grep -m 1 -oP '(?<=Address=).*' /etc/systemd/network/br0.network)
        br0_fixed_ip_OS2=$(tac /etc/systemd/network/br0.network | grep -m 1 -oP '(?<=Address=).*')
        [ "${br0_fixed_ip_OS}" == "${br0_fixed_ip}" ] || sed -i "s^${br0_fixed_ip_OS}^${br0_fixed_ip}^" /etc/systemd/network/br0.network
        [ "${br0_fixed_ip_OS2}" == "${br0_fixed_ip2}" ] || sed -i "s^${br0_fixed_ip_OS2}^${br0_fixed_ip2}^" /etc/systemd/network/br0.network
	need_restart_services="$need_restart_services systemd-networkd"
fi
echo "br0 configure done"

# wlan0 configuration
if [ -z "$wfb_integrated_wnic" ]; then
	# managed wlan0 by NetworkManager
	[ -f /etc/network/interfaces.d/wfb-wlan0 ] && rm /etc/network/interfaces.d/wfb-wlan0
	nmcli device | grep -q "^wlan0.*unmanaged.*" && nmcli device set wlan0 managed yes

	# wlan0 station mode configuration
	echo "start configure wlan0 station mode"
	# If no connection named radxa, create one to automatically connect to the unencrypted WiFi named OpenIPC.
	[ -f /etc/NetworkManager/system-connections/wlan0.nmconnection ] || nmcli con add type wifi ifname wlan0 con-name wlan0 ssid OpenIPC
	# If the WiFi configuration in gs.conf is not empty and changes, modify the WiFi connection information according to the configuration file
	if [[ -f /etc/NetworkManager/system-connections/wlan0.nmconnection && -n $WIFI_SSID && -n $WIFI_Encryption && -n $WIFI_Password ]]; then
		WIFI_SSID_OS=$(nmcli -g 802-11-wireless.ssid connection show wlan0)
		WIFI_Encryption_OS=$(nmcli -g 802-11-wireless-security.key-mgmt connection show wlan0)
		WIFI_Password_OS=$(nmcli -s -g 802-11-wireless-security.psk connection show wlan0)
		[[ "$WIFI_SSID_OS" == "$WIFI_SSID" && "$WIFI_Encryption_OS" == "$WIFI_Encryption" && "$WIFI_Password_OS" == "$WIFI_Password" ]] || nmcli con modify wlan0 ssid ${WIFI_SSID} wifi-sec.key-mgmt ${WIFI_Encryption} wifi-sec.psk ${WIFI_Password}
		nmcli con down wlan0 && nmcli con up wlan0
	fi
	echo "wlan0 station mode configure done"

	# wlan0 hotspot mode configuration
	echo "start configure wlan0 hotspot mode"
	if [[ -f /etc/NetworkManager/system-connections/hotspot.nmconnection && -n $Hotspot_SSID && -n $Hotspot_Password && -n $Hotspot_ip ]];then
		Hotspot_SSID_OS=$(nmcli -g 802-11-wireless.ssid connection show hotspot)
		Hotspot_Password_OS=$(nmcli -s -g 802-11-wireless-security.psk connection show hotspot)
		Hotspot_ip_OS=$(nmcli -g ipv4.addresses con show hotspot)
		[[ "$Hotspot_SSID_OS" == "$Hotspot_SSID" && "$Hotspot_Password_OS" == "$Hotspot_Password" ]] || nmcli connection modify hotspot ssid $Hotspot_SSID wifi-sec.psk $Hotspot_Password
		[[ "$Hotspot_ip_OS" == $Hotspot_ip ]] || nmcli connection modify hotspot ipv4.method shared ipv4.addresses $Hotspot_ip
	elif [[ -d /sys/class/net/wlan0 && -n $Hotspot_SSID && -n $Hotspot_Password && -n $Hotspot_ip ]]; then
		nmcli dev wifi hotspot con-name hotspot ifname wlan0 ssid $Hotspot_SSID password $Hotspot_Password
		nmcli connection modify hotspot ipv4.method shared ipv4.addresses $Hotspot_ip autoconnect no
	else
		echo "no wlan0 or hotspot setting is blank"
	fi
	[[ -d /sys/class/net/wlan0 && "$WIFI_mode" == "hotspot" ]] && ( sleep 15; nmcli connection up hotspot ) &
	echo "wlan0 hotspot mode configure done"
fi

# radxa0 dnsmasq configuration
if [[ -f /etc/network/interfaces.d/radxa0 && -n "$gadget_net_fixed_ip" ]]; then
	# Check whether the configuration in gs.conf is consistent with radxa0. If not, update it.
	radxa0_fixed_ip_OS=$(grep -oP "(?<=address\s).*" /etc/network/interfaces.d/radxa0)
	[ "$radxa0_fixed_ip_OS" == "${gadget_net_fixed_ip}" ] || sed -i "s^${radxa0_fixed_ip_OS}^${gadget_net_fixed_ip}^" /etc/network/interfaces.d/radxa0
	grep -q "${gadget_net_fixed_ip_addr}" /etc/network/interfaces.d/radxa0 || sed -i "s/--listen-address=.*,12h/--listen-address=${gadget_net_fixed_ip_addr} --dhcp-range=${gadget_net_fixed_ip_sub}.11,${gadget_net_fixed_ip_sub}.20,12h/" /etc/network/interfaces.d/radxa0
fi
echo "radxa0 usb gadget network configure done"

# Update REC_Dir in smb.conf
grep -q "$REC_Dir" /etc/samba/smb.conf || ( sed -i "/\[Videos\]/{n;s|.*|   ${REC_Dir}|;}" /etc/samba/smb.conf && need_restart_services="$need_restart_services smbd nmbd")

# some configuration need reboot to take effect
[ "$need_u_boot_update" == "1" ] && u-boot-update
[ "$need_reboot" == "1" ] && reboot
[ -n "$need_restart_services" ] && systemctl restart $need_restart_services