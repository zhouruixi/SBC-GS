#!/bin/bash

set -e
source /config/gs.conf

# change wifi mode between station and hotspot
function change_wifi_mode() {
	if [ ! -d /sys/class/net/wlan0 ]; then
		echo "WARING: no wlan0 found, can't switch wifi mode."
		exit 0
	elif [ "$wfb_integrated_wnic" == "wlan0" ]; then
		echo "WARING: wlan0 used by wfb, can't switch wifi mode."
		exit 0
	else
		wlan0_connected_connection=$(nmcli device status | grep '^wlan0.*connected' | tr -s ' ' | cut -d ' ' -f 4)
		case "$wlan0_connected_connection" in
			hotspot)
				nmcli connection up wlan0
				sleep 5
				;;
			wlan0)
				nmcli connection up hotspot
				sleep 5
				;;
			*)  echo "connection is unknow"
				;;
		esac
	fi
}

# change usb otg mode between host and device
function change_otg_mode() {
	local otg_mode_LED_PIN_info=$(gpiofind PIN_${otg_mode_LED_PIN})
	local otg_mode_file="/sys/kernel/debug/usb/fcc00000.dwc3/mode"
	local otg_mode=$(cat $otg_mode_file)
	if [ "$otg_mode" == "host" ]; then
		echo device > $otg_mode_file
		sleep 0.2
		[ -d /sys/kernel/config/usb_gadget/fcc00000.dwc3/functions/ffs.adb ] || systemctl start radxa-adbd@fcc00000.dwc3.service
		[ -f /sys/class/net/radxa0 ] || systemctl start radxa-ncm@fcc00000.dwc3.service
		sleep 1
		# [ "$(ip link ls radxa0 | grep -oP '(?<=state ).+(?=mode)')" == "DOWN"  ] && ifup radxa0
		(
		while true; do
			# Blink green power LED
			gpioset -D $otg_mode_LED_drive -m time -s 1 $otg_mode_LED_PIN_info=1
			gpioset -D $otg_mode_LED_drive -m time -s 1 $otg_mode_LED_PIN_info=0
		done
		) &
		local pid_led=$!
	elif [ "$otg_mode" == "device" ]; then
		echo host > $otg_mode_file
		[ -z "$pid_led" ] || kill $pid_led
		sleep 1.2
		gpioset -D $otg_mode_LED_drive -m time -s 1 $otg_mode_LED_PIN_info=1
	else
		echo "otg mode is unkonw"
	fi

}

# scan wfb wifi channel
function scan_wfb_channel() {
	/home/radxa/gs/channel-scan.sh
}

# Add more custom functions above

function button_action() {
	local gpio_info=$(gpiofind PIN_${1})
	while gpiomon -r -s -n 1 -B pull-down ${gpio_info}; do
		sleep 0.05
		[ "$(gpioget ${gpio_info})" == "1" ] || continue
		local button_press_uptime=$(cut -d ' ' -f 1 /proc/uptime | tr -d .)
		gpiomon -f -s -n 1 -B pull-down ${gpio_info}
		local button_release_uptime=$(cut -d ' ' -f 1 /proc/uptime | tr -d .)
		local button_pressed_time=$((${button_release_uptime} - ${button_press_uptime}))
		if [ $button_pressed_time -lt 200 ]; then
			echo "single"
		elif [ $button_pressed_time -ge 200 ]; then
			echo "long"
		fi
		break
	done
}

function execute_button_function() {
	local gpio_pin="${1}_PIN"
	local single_press_function="${1}_single_press"
	local long_press_function="${1}_long_press"
	[ -z "${!gpio_pin}" ] && exit 0
	[ -z "${!single_press_function}" ] && [ -z "${!long_press_function}" ] && exit 0
	while true; do
		local action=$(button_action ${!gpio_pin})
		case $action in
			single)
				${!single_press_function}
				;;
			long)
				${!long_press_function}
				;;
			*)
				echo "unknow button action"
		esac

	done
}

execute_button_function BTN_Q2 &
execute_button_function BTN_Q3 &
execute_button_function BTN_CU &
execute_button_function BTN_CD &
execute_button_function BTN_CL &
execute_button_function BTN_CR &
execute_button_function BTN_CM &

wait
