#!/bin/bash

set -e

# Size, MB
SIZE_DISK=16
TMP_DISK="newImage.img"

# Protection against duplicate creation
if $(sgdisk -p $1 | grep -q config);then
	echo "Warning: The config section already exists"
	exit 0
fi

# Checking free space
diskFreeSpace=$(df -PhB1 . | tail -1 | awk '{print $4}')
fileSize=$(du -B1 "$1" | awk '{print $1}')
if [ $diskFreeSpace -lt $(($fileSize*2)) ];then
	echo "Error: not enough free space"
	exit 1
fi

# Getting the current disk layout
sfdisk_output=$(sfdisk -d $1)
label=$(echo "$sfdisk_output" | grep 'label:' | tr -d ' ' | cut -d ':' -f 2)
label_id=$(echo "$sfdisk_output" | grep 'label-id:' | tr -d ' ' | cut -d ':' -f 2)
device=$(echo "$sfdisk_output" | grep 'device:' | tr -d ' ' | cut -d ':' -f 2)
unit=$(echo "$sfdisk_output" | grep 'unit:' | tr -d ' ' | cut -d ':' -f 2)
first_lba=$(echo "$sfdisk_output" | grep 'first-lba:' | tr -d ' ' | cut -d ':' -f 2)
last_lba=$(echo "$sfdisk_output" | grep 'last-lba:' | tr -d ' ' | cut -d ':' -f 2)
sector_size=$(echo "$sfdisk_output" | grep 'sector-size:' | tr -d ' ' | cut -d ':' -f 2)
partedList="$(echo "$sfdisk_output" | grep $device.)"
start_sector=$(echo $partedList | gawk '{if ( match ( $0, /start=\W*([0-9]*)(.*)/, a ) ) print a[1] }') 
gptReserveSizeSector=$((($(du -b "$1" | awk '{print $1}')/$sector_size - $last_lba)))
mbToSector=$((1024*1024/$sector_size)) # How many sectors in a megabyte
size_disk_sectors="$(($SIZE_DISK*$mbToSector))"
full_lba=$(($last_lba+$size_disk_sectors))

# Create a new disk with an indent of SIZE_DISK
if [ -f ${TMP_DISK} ];then 
	echo "Deleting a $TMP_DISK"
	rm ${TMP_DISK} 
fi

echo "Create a new disk"

# Copy sectors and bootloader
skip_mb=$(($start_sector/$mbToSector)) # We do not read empty blocks at the beginning of the img image, in MB
dd if=$1 of=$TMP_DISK bs=1M count=$skip_mb

# Add 16M + images
seek_mb=$(($skip_mb + $SIZE_DISK)) # Seek +16М
dd if=$1 of=$TMP_DISK bs=1M skip=$skip_mb seek=$seek_mb status=progress

# Add in end length equals first_lba (need for sgdisk -ge)
size_img=$(($(du -b "$TMP_DISK" | awk '{print $1}')/$sector_size))
r34=$(($size_img - $full_lba))
if [ $r34 -ne $gptReserveSizeSector ];then
	echo "Error: The size of the new image is out of bounds by $(($r34-$gptReserveSizeSector)) bytes"
	exit 1
fi

if [ $gptReserveSizeSector -le $first_lba ];then
	# Increases the end of the disk to the size of first-lba
	dd if=/dev/zero of=$TMP_DISK bs=$sector_size count=$(($first_lba-$gptReserveSizeSector)) seek=$(($(du -b "$TMP_DISK" | awk '{print $1}')/512)) 
fi

size_img=$(($(du -b "$TMP_DISK" | awk '{print $1}')/$sector_size))
r34=$(($size_img - $full_lba))
if [ $r34 -gt $first_lba ];then
	echo "Error: GPT backup partition extends beyond first-lba by $(($r34-$first_lba)) bytes"
	exit 1
fi

if [ ! -f $TMP_DISK ];then
	echo "Error: failed to create file '${TMP_DISK}'"
	exit 1
fi

# Recalculates indents of existing volumes
i=2
new_partition=""
seek_sector=$(($seek_mb*$mbToSector)) # Seek sector
while IFS= read -r line
do
  new_partition="${new_partition}NewPartition${i} $(echo $line | gawk '{if ( match ( $0, /(.*)(:.*start=)\W*([0-9]*)(.*)/, a ) ) print a[2]a[3]+('$size_disk_sectors')a[4]}' )"$'\n'
  i=$(($i+1))
done < <(printf '%s\n' "$partedList")

# Create a new markup
cat <<EOF | sfdisk $TMP_DISK
label: ${label}
label-id: ${label_id}
device: NewPartition
unit: ${unit}
first-lba: ${first_lba}
last-lba: ${full_lba}
sector-size: ${sector_size}

NewPartition1 : start=$start_sector, size=$size_disk_sectors, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name="config"
${new_partition}
EOF

# bootdisk flag
sgdisk -A 2:set:2 $TMP_DISK

sgdisk -ge $TMP_DISK
sgdisk -v $TMP_DISK

LOOPDEV=$(losetup -P --show -f $TMP_DISK)
	CONFIG_PART=$(sgdisk -p $LOOPDEV | grep "config" | tail -n 1 | tr -s ' ' | cut -d ' ' -f 2)
	BOOT_PART=$(sgdisk -p $LOOPDEV | grep "boot" | tail -n 1 | tr -s ' ' | cut -d ' ' -f 2)
	ROOT_PART=$(sgdisk -p $LOOPDEV | grep "rootfs" | tail -n 1 | tr -s ' ' | cut -d ' ' -f 2)

	# Formatting
	mkfs.fat ${LOOPDEV}p${CONFIG_PART}

	# We define the name of the single-board computer
	mount ${LOOPDEV}p${ROOT_PART} /mnt
		BOARD=$(cat /mnt/etc/hostname)
		echo "UUID=$(blkid -s UUID -o value ${LOOPDEV}p${CONFIG_PART})  /config vfat defaults,x-systemd.automount 0 2" >> /mnt/etc/fstab
	umount /mnt

	# Changing the partition boot in U-Boot
	case $BOARD in
		orangepi3b)
			mount ${LOOPDEV}p${BOOT_PART} /mnt
				sed -i "s/rootdev=UUID=.*/rootdev=\/dev\/disk\/by-partuuid\/$(blkid -s PARTUUID -o value ${LOOPDEV}p${ROOT_PART})/" /mnt/orangepiEnv.txt
				sed -i "s/if test \"\${devtype}\".*/setenv partuuid \"$(blkid -s PARTUUID -o value ${LOOPDEV}p${BOOT_PART})\"/" /mnt/boot.cmd
				sed -i "/# default values/a setenv devnum \"\${devnum}:$(($ROOT_PART-1))\"" /mnt/boot.cmd
				mkimage -A arm -O linux -T script -C none -a 0 -e 0 -d /mnt/boot.cmd /mnt/boot.scr >/dev/null
			umount /mnt
		;;
	esac
losetup -d $LOOPDEV

# Replace the original img image
mv $TMP_DISK $1

echo "Done!"
exit 0