Main Features
-------------

* __Centralize configuration file in fat32 partition.__ Use a single configuration file to configure almost everything you need. The configuration file path is `/config/gs.conf` and linked to `/etc/gs.conf`. The partition mount to /config is fat32 format, configuration file can be accessed and edited directly on Windows PC. See configuration part for detial.
* __Default wfb key file in fat32 partition.__ `/config/gs.key` and linked to `/etc/gs.key`.
* __Button support.__ There are 8 buttons in plan, they are `up, down, left, right, middle and quick 1, 2, 3` buttons.
* __Keyboard support.__ Map keyboard key UP, DOWN, LEFT, RIGHT, 1, 2, 3 to button up, down, left, right, quick 1, 2, 3.
* __LED support.__ Currently support `video record LED (Red)` and `power LED (Green)`. The green and red LED turn on after the SBC is powered on. Red LED turn off after the system is startup completed. The red LED will blink when video record is turn on. The green LED will blink when OTG mode is switched to device.
* __Multiple types of network support.__ Support `WiFi`, `Ethernet` and `USB Net`, See Network Configuration for details.
* __Optional video player.__ Support pixelpilot, fpvue, gstreamer as Video player. Gstreamer not support OSD.
* __Multiple USB OTG gadget functions.__ Support `adbd` and `CDC NCM`, `CDC ACM` and `MASS` supported in plan. Use a data cable to connect the computer and the SBC OTG port, adb device and an additional NCM network card will appear on the computer. NCM  can auto get ip address with DHCP.
* __Temperature monitoring and active cooling.__ Support monitoring `RK3566` and `RTL8812EU` temperature and automatically adjust PWM fan speed according to temperature.
* __Multiple WiFi card drivers.__ Currently supports `RTL8812AU, RTL8812EU, RTL8812BU, RTL8812CU, RTL8814AU, RTL8731BU`.
* __USB WiFi card hot plug.__ Support multiple USB WiFi cards with Hotplugging.
* __Three wifibroadcast working modes.__ `standalone` mode is the native mode with the best compatibility, but hot-plugging USB WiFi card will briefly interrupted the stream. `aggregator` mode will run wfb_rx aggregator on boot, and run wfb_rx forwarder for each USB WiFi card, hot-plugging USB WiFi card will not interrupt the stram and can receive streams from other external devices through the network like an openwrt router, but may add a little delay (<1ms?). `cluster` mode.
* __Share config and videos with smb.__ Anonymous access with root permissions is enabled by default, which allows you to easily modify configurations, obtain and delete record files. Enter \\192.168.x.x (SBC IP address) in the Windows Explorer address bar to access.
* __Auto extend root partition and rootfs.__ The root partition and rootfs will automatically `expand to the size specified in gs.conf->rootfs_reserved_space` on initial startup.
* __exfat partition for video recordings.__ Automatically create an `exfat partition` using all remaining space during initial startup. The partition will be `mounted to /home/radxa/Videos` for storing video recordings, can get the record files through smb or insert the TF card into the computer.
* __Sequentially increasing video file names.__ Gstreamer record video files name sequentially starting from 1000.mkv, e.g. `1000.mkv, 1001.mkv`. PixelPilot record file name use template `xxxx_record_%Y-%m-%d_%H-%M-%S.mp4`, e.g. `0000_record_2025-02-15_17-26-25.mp4, 0001_record_2025-02-15_17-26-35.mp4`. CAUTION: Radxa zero3 have no RTC battery, datetime may incorrect without internet, gps or external RTC.
* __send stream over USB tethering and Ethernet.__ Video and telemetry stream can send to other device over USB tethering or Ethernet, witch can be played with Android QGroundControl,PixelPilot etc. Notice: share stream using multicast by default, not working with windows QGroundControl.
* __Forward SBC port to IPC over wfb tun.__ Forward SBC port 2222/8080 to IPC port 22/80 over wfb tun.
* __Web terminal.__ Use [ttyd](https://github.com/tsl0922/ttyd) for web terminal. Default port is 81.
* __WFB channel scan.__
* __Record to external disk.__ Save record files to the first partition of the external disk when plug in, support vfat, exfat, ext4 formats. Recommended to umount or shutdown SBC before unplugging the disk. **WARING:** Do not unplugging the disk when recoding, may corrupt the file system.
* __Version in /etc/gs-release.__
* __Auto build with github action.__


Configuration [ [gs.conf](https://github.com/zhouruixi/SBC-GS/blob/main/gs/gs.conf) for details ]
-------------------------------------

### 1. Button Configuration
There are some built-in functions that can bind to button behaviors.
* Buttons
    + Q1, Q2, Q3, CU, CD, CL, CR. (PIN configured in the GPIO section.)
* Button behaviors
    + single press
    + long press (Pressing for more than 2 seconds)
* Button functions
    + __change_wifi_mode:__ change wifi mode between station and hotspot.(Radxa zero 3W)
    + __change_otg_mode:__ change usb otg port between host and device.
    + __scan_wfb_channel:__ search wifi channel used by drone.
    + __toggle_record:__ start or stop record.
    + __toggle_stream:__ start or stop stream service.
    + __cleanup_record_files:__ cleanup record files in order of file names until remaining space(MB) of record partition is large than `rec_dir_freespace_min` settings.  
      **CAUTION:** Second long press in 60 seconds after first long press will delete all record files.
    + __apply_conf:__ check and apply configuration in gs.conf.
    + __shutdown_gs:__ shutdown ground station.
    + __reboot_gs:__ reboot ground station.
    + __mount_extdisk:__ mount external disk first partition to record directory. **CAUTION:** This function will auto execute by udev rules when external disk is plug in. Do not use for other purposes.
    + __ummount_extdisk:__ umount external disk.
* Default button behavior function
    + Q1
        - single press: toggle_record
        - long press: cleanup_record_files
        - second long press: delete all record files(second long press in 60 seconds after first long press).
    + Q2
        - single press: scan_wfb_channel
        - long press: change_otg_mode
    + Q3
        - single press: null
        - long press: change_wifi_mode
    + KEY_Q
        - single press: null
        - long press: Stop monitoring and use the keyboard as normal. Reseat the keyboard to using as buttons.
    + KEY_S
        - single press: null
        - long press: shutdown_gs
    + KEY_R
        - single press: null
        - long press: reboot_gs

### 2. GPIO Configuration
Default buttons and LEDs PIN number.
* Quick button PIN
    + btn_q1_pin='32'
    + btn_q2_pin='38'
    + btn_q3_pin='40'
* Custom button PIN
    + btn_cu_pin='16'
    + btn_cd_pin='18'
    + btn_cl_pin='13'
    + btn_cr_pin='11'
* LED PIN
    + red_led_pin='22'
    + green_led_pin='15'
    + blue_led_pin='12'

### 3. Network Configuration
* __Onboard WiFi:__ `wifi0`
    + `station mode:` Default connect to an open WiFi named `OpenIPC` if not configured.
    + `hotspot mode:` Default SSID is `SBC-GS` with password `12345678`, IP is `192.168.4.1/24`
* __Bridge:__ `br0` Default `DHCP client` with static IP `192.168.1.20/24, 10.0.36.254/24`
* __Onboard Ethernet:__ `eth0` Default slave of br0.
* __USB Ethernet:__ `eth1` Default slave of br0.
* __USB tethering:__ `usb0` Default slave of br0.
* __USB gadget ncm:__ `radxa0` Default `DHCP server` with static IP `192.168.2.20/24`

### 4. Video Configuration
* __video_on_boot:__ used to control showing video or terminal console after startup. Default is `yes`. Set it to `no` will boot into the terminal and only recommended for development and debugging.
* __screen_mode:__ used to set the screen resolution and refresh rate. Support <width>x<heigth>@<fps>(e.g. 1920x1080@60), max-fps, max-res and empty. Default is empty and will auto detect by pixelpilot or SBC. Recommended set it manually only when preferred screen mode is not the best. __CAUTION:__ Resolution is limited to 1920x1080 by radxa, can changed by setting `max_resolution_4k` to `yes` in `System Configuration` section.
* __video_player:__ `pixelpilot` or `gstreamer`.
* __video_codec:__ `h265` or `h264`.
* __osd_enable:__ Enable or disable OSD. pixelpilot video player support mulit OSD types. gstreamer video player only support wfb-ng-osd.
* __osd_fps:__ Pixelpilot OSD refresh rate.
* __osd_type:__ `mavlink`(Native OSD provided by pixelpilot), `msposd_air`(msposd air side rendering), `msposd_gs`(msposd ground side rendering)
* __msposd_gs_method:__ msposd message transmission method. Can be `tunnel`(over wfb tunnel) or `wfbrx`(over wfb tx rx pair)
* __msposd_gs_port:__ The port that msposd listens on and uses to obtain data.
* __msposd_gs_fps:__ Max MSP Display refresh rate.
* __msposd_gs_ahi:__ Graphic AHI mode.
* __osd_config_file:__ pixelpilot's osd config file. Default is blank and auto select according to `osd_type`. Can manually set the configuration file e.g. `/config/pixelpilot_osd_custom.json`.
    + mavlink    => /etc/pixelpilot/pixelpilot_osd.json
    + msposd_air => /etc/pixelpilot/pixelpilot_osd_simple.json
    + msposd_gs  => /etc/pixelpilot/pixelpilot_msposd.json

### 5. Record Configuration
* `rec_dir`: the record storage location. Default is `/home/radxa/Videos`.
* `rec_dir_freespace_min`: the minimum remaining space before recording. When press the record button, if remaining space is lower than this value, it will prompt that there is insufficient space and the recording will not start. Default is `1000`MB.
* `rec_fps`: Record video fps and must same video fps set on drone. Default is `60`.
* __CAUTION:__ OSD will not be recorded.

### 6. Wifibroadcast Configuration

### 7. System Configuration
#### Recommended GPIO Functions
| Purpose#1        | Recommended Function#1     | Pin#1 | Pin#2 | Recommended Function#2    | Purpose#2        |
| ---------------: | -------------------------: | ----: | ----- | ------------------------- | ---------------- |
| +3.3V            | +3.3V                      | 1     | 2     | +5.0V                     | +5.0V            |
| telemetry        | UART3_RX_M0                | 3     | 4     | +5.0V                     | +5.0V            |
| telemetry        | UART3_TX_M0                | 5     | 6     | GND                       | GND              |
| PWM_FAN          | PWM14_M0                   | 7     | 8     | UART2_TX_M0               | DEBUG            |
| GND              | GND                        | 9     | 10    | UART2_RX_M0               | DEBUG            |
| BTN_R            | GPIO3_A1                   | 11    | 12    | GPIO3_A3                  | BTN_L            |
| BTN_U            | GPIO3_A2                   | 13    | 14    | GND                       | GND              |
| BTN_D            | GPIO3_B0                   | 15    | 16    | PWM8_M0 / UART4_RX_M1     | AAT_SERVO        |
| +3.3V            | +3.3V                      | 17    | 18    | PWM9_M0 / UART4_TX_M1     | AAT_SERVO        |
| SPI_SCREEN       | SPI3_MOSI_M1 / PWM15_IR_M1 | 19    | 20    | GND                       | GND              |
| SPI_SCREEN       | SPI3_MISO_M1 / UART9_TX_M1 | 21    | 22    | GPIO3_C1                  | SPI_SCREEN       |
| SPI_SCREEN       | SPI3_CLK_M1 / PWM14_M1     | 23    | 24    | SPI3_CS0_M1 / UART9_RX_M1 | SPI_SCREEN       |
| GND              | GND                        | 25    | 26    | NC                        | NC               |
| COMPASS / USB D+ | I2C4_SDA_M0 / USB D+       | 27    | 28    | I2C4_SCL_M0 / USB D-      | COMPASS / USB D- |
| SPI_SCREEN       | GPIO3_B3                   | 29    | 30    | GND                       | GND              |
| BTN_Q1           | GPIO3_B4                   | 31    | 32    | UART5_TX_M1               | GPS              |
| GPS              | UART5_RX_M1                | 33    | 34    | GND                       | GND              |
| BTN_Q2           | GPIO3_A4                   | 35    | 36    | GPIO3_A7                  | RECORD_RED_LED   |
| BTN_Q3           | GPIO1_A4                   | 37    | 38    | GPIO3_A6                  | PWR_GREEN_LED    |
| GND              | GND                        | 39    | 40    | GPIO3_A5                  | RC_BLUE_LED      |

### 8. Cooling Configuration


Files and Services
------------------

* __build files:__ script files for build images
* __workflows files:__ Auto build images using github action
* __gs files:__
    1. Configuration file `/config/gs.conf`
    2. wfb key file `/config/gs.key`
    3. script files `/home/radxa/gs/[button.sh, channel-scan.sh, fan.sh, gs-init.sh, gs.sh, stream.sh, wfb.sh]`
    4. udev rules in `/etc/udev/rules.d`
* __Services:__
    1. `gs`.service
    2. `stream`.service (temporary unit)
    3. `button`.service (temporary unit)
    4. `fan`.service (temporary unit)
    5. unnamed temporary services started for each USB WiFi card in wfb aggregator mode
```bash
GS Directory Tree
/
├── boot
│   └── dtbo
│       ├── rk3566-dwc3-otg-role-switch.dtbo
│       └── rk3566-hdmi-max-resolution-4k.dtbo.disabled
├── config
│   ├── custom-sample.conf
│   ├── gs.conf
│   └── gs.key
├── etc
│   ├── alink.conf -> /config/alink.conf
│   ├── default
│   │   └── wifibroadcast -> /tmp/wifibroadcast
│   ├── gs.conf -> /config/gs.conf
│   ├── gs.key -> /config/gs.key
│   ├── gs-release
│   ├── iptables
│   │   └── rules.v4
│   ├── network
│   │   └── interfaces.d
│   │       └── radxa0
│   ├── NetworkManager
│   │   ├── conf.d
│   │   │   └── 00-gs-unmanaged.conf
│   │   └── system-connections
│   │       ├── hotspot.nmconnection
│   │       └── wifi0.nmconnection
│   ├── pixelpilot
│   │   ├── pixelpilot_msposd.json
│   │   ├── pixelpilot_osd.json
│   │   └── pixelpilot_osd_simple.json
│   ├── samba
│   │   └── smb.conf
│   ├── systemd
│   │   ├── network
│   │   │   ├── br0.netdev
│   │   │   ├── br0.network
│   │   │   ├── dummy0.netdev
│   │   │   ├── dummy0.network
│   │   │   ├── eth0.network
│   │   │   ├── eth1.network
│   │   │   └── usb0.network
│   │   └── system
│   │       ├── gs-init.service
│   │       ├── gs.service
│   │       ├── multi-user.target.wants
│   │       │   ├── gs-init.service -> /etc/systemd/system/gs-init.service
│   │       │   └── gs.service -> /etc/systemd/system/gs.service
│   │       ├── ttyd.service
│   │       └── webui.service
│   ├── udev
│   │   └── rules.d
│   │       ├── 98-rename.rules
│   │       └── 99-GS.rules
│   └── wifibroadcast.cfg -> /tmp/wifibroadcast.cfg
├── gs
│   ├── button-kbd.py
│   ├── button.sh
│   ├── channel-scan.sh
│   ├── fan.sh
│   ├── gs-applyconf.sh
│   ├── gs-init.sh
│   ├── gs.sh
│   ├── rk3566-dwc3-otg-role-switch.dts
│   ├── rk3566-hdmi-max-resolution-4k.dts
│   ├── stream.sh
│   ├── webui
│   │   ├── plotter.py
│   │   ├── requirements.txt
│   │   ├── settings_webui.yaml
│   │   ├── static
│   │   │   ├── css
│   │   │   │   └── bootstrap.min.css
│   │   │   └── js
│   │   │       ├── bootstrap.bundle.min.js
│   │   │       ├── jquery-3.6.0.min.js
│   │   │       └── webui.js
│   │   ├── templates
│   │   │   ├── filemanager.html
│   │   │   ├── index.html
│   │   │   ├── plotter.html
│   │   │   └── viewer.html
│   │   ├── venv -> python-venv
│   │   └── webui.py
│   └── wfb.sh
├── tmp
│   ├── wifibroadcast.cfg
│   └── wifibroadcast.default
├── usr
│   └── local
│       └── bin
│           ├── alink
│           ├── msposd
│           ├── pixelpilot
│           ├── ttyd
│           └── wfb-ng-osd
└── Videos

```


Hardware
--------

__Designed for and tested on Radxa Zero 3W/3E only.__
* __Buttons:__ All buttons must connect to 3.3V.
* __LEDs:__
    1. GPIO work in `Push-Pull` mode. `GPIO->Resistor->LED->GND`
    2. GPIO work in `Open-Drain` mode.
    ```
    3V3->Resistor--->LED->GND
                  │  
                 GPIO
    ```


Troubleshooting
---------------

1. Access to SBC console. Default username/password is radxa/radxa and root/root
    * ssh over network with wireless(hotspot/station), ethernet or usb gadget ncm.
    * [serial console](https://docs.radxa.com/en/zero/zero3/low-level-dev/serial) with usb uart.
    * terminal console with keyboard.
    * adb with usb otg.
2. Check gs service logs
    * `systemctl status gs`
    * `journalctl -u gs`


TODO
----

* Change the built-in LED to a normal GPIO LED
* Screenshots
* Record video playback


Known issues
------------

* When WiFi uses 192.168.1.0/24 network segment, SBC cannot be accessed via WiFi. Temporary solution: Modify br0 default network configuration, e.g. modify `br0_fixed_ip` to `192.168.3.20/24`.
