#!/bin/bash

# 切换OTG端口为device模式
if [ "$(cat /sys/kernel/debug/usb/fcc00000.dwc3/mode)" == "host" ]; then
	echo device > /sys/kernel/debug/usb/fcc00000.dwc3/mode || exit 1
	sleep 0.5
fi

# 挂载ConfigFS
grep -q "configfs /sys/kernel/config" /proc/mounts || mount -t configfs none /sys/kernel/config

# 加载 libcomposite 模块
[ -d /sys/kernel/config/usb_gadget ] || modprobe libcomposite

# 若存在 gadget g1 则先删除
if [ -d /sys/kernel/config/usb_gadget/g1 ]; then
	echo ">>>>>>>>>>>>g1 is exist! delete it!"
	# stop adb
	# [ -e /var/run/adbd.pid ] && start-stop-daemon --stop --oknodo --pidfile /var/run/adbd.pid --remove-pidfile --retry 5
	# [ -e /dev/usb-ffs/adb ] && umount /dev/usb-ffs/adb
	# [ -e /dev/usb-ffs ] && rmdir /dev/usb-ffs/adb /dev/usb-ffs
	systemctl stop serial-getty@ttyGS0.service
	cd /sys/kernel/config/usb_gadget/g1
	echo '' > UDC
	#remove all links
	find . -type l -exec rm -v {} \;
	find configs -name 'strings' -exec rmdir -v {}/0x409 \;
	ls -d configs/* | xargs rmdir -v
	ls -d strings/* | xargs rmdir -v
	ls -d functions/* | xargs rmdir -v
	cd ..
	rmdir -v g1
	modprobe -r libcomposite > /dev/null 2>&1 
	echo ">>>>>>>>>>>>>Delete success, Run script again to create the gadget!!"
	exit 0
fi

# 定义一些变量
HOST_MAC="48:6f:73:74:50:43"
DEVICE_MAC="42:61:64:55:53:42"
MASS_FILE=/dev/mmcblk0p4
[ -b /dev/mmcblk1p4 ] && MASS_FILE=/dev/mmcblk1p4
# MASS_FILE=/root/usbdisk.img
# 若指定块设备不存在则创建一个测试用镜像
# if [ ! -e $MASS_FILE ]; then
# 	echo "Create $MASS_FILE format with vfat for Mass Storage......"
# 	dd if=/dev/zero of=$MASS_FILE bs=1M count=8
# 	mkfs.vfat $MASS_FILE
# fi

###############开始创建gadget################
echo ">>>>>>>>>>>>>Starting create gadget......"
cd /sys/kernel/config/usb_gadget/
mkdir g1
cd g1
echo "0x1d6b" > "idVendor"  # Linux Foundation
echo "0x0104" > "idProduct" # Multifunction Composite Gadget
echo "0x0100" > "bcdDevice" # v1.0.0
echo "0x0200" > "bcdUSB"	# USB 2.0
echo "0xEF" > "bDeviceClass"
echo "0x02" > "bDeviceSubClass"
echo "0x01" > "bDeviceProtocol"

mkdir -p strings/0x409
cat /proc/device-tree/serial-number > strings/0x409/serialnumber
uname -r > strings/0x409/manufacturer
hostname -s > strings/0x409/product

# 创建config1
echo ">>>>>>>>>>>Create config1: ACM + Mass_Storage + NCM ......"
mkdir -p configs/c.1/strings/0x409
echo "0x80" > configs/c.1/bmAttributes
echo 250 > configs/c.1/MaxPower
echo "config1: ACM + Mass_Storage + NCM" > configs/c.1/strings/0x409/configuration

# 创建NCM function
echo ">>>>>>>>Create RNDIS ......"
mkdir -p functions/ncm.usb0
echo "$HOST_MAC" > functions/ncm.usb0/host_addr
echo "$DEVICE_MAC" > functions/ncm.usb0/dev_addr

# 创建串口function
echo ">>>>>>>>Create serial ......"
mkdir -p functions/acm.gs0

# 创建mass_storage function
echo ">>>>>>>>Create Mass_Storage ......"
mkdir -p functions/mass_storage.usb0
echo 1 > functions/mass_storage.usb0/stall
echo 1 > functions/mass_storage.usb0/lun.0/ro
echo 1 > functions/mass_storage.usb0/lun.0/removable
echo $MASS_FILE > functions/mass_storage.usb0/lun.0/file

# 创建adb function
# mkdir -p functions/ffs.adb
# mkdir -p /dev/usb-ffs/adb
# mount -o uid=2000,gid=2000 -t functionfs adb /dev/usb-ffs/adb
# export service_adb_tcp_port=5555
# start-stop-daemon --start --oknodo --make-pidfile --pidfile /var/run/adbd.pid --startas /usr/bin/adbd --background
# sleep 2


# 将对应function软连到c.1下面, 即启用该function，MAX 3 functions
ln -s functions/ncm.usb0 configs/c.1/
ln -s functions/acm.gs0 configs/c.1/
ln -s functions/mass_storage.usb0 configs/c.1/
# ln -s functions/ffs.adb configs/c.1/

# 将gadget绑定到USB接
echo ">>>>>>>>>>>Bind config1 to $(ls /sys/class/udc)"
ls /sys/class/udc > UDC
echo "All is done, Run script again to delete the gadget!"

# 启动串口控制台
sleep 0.5
systemctl start serial-getty@ttyGS0.service
