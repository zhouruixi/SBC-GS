#!/bin/bash

set -e -x

# Size, MB
SIZE_DISK=16
SIZE_SECTORS="$(($SIZE_DISK*2048))"
TMP_DISK="newImage.img"
FIRST_SECTOR=32768 # The number must be a multiple of 2048. Minimum=2048

# Protection against duplicate creation
if $(sgdisk -p $1 | grep -q config);then
	echo "Error: The config section already exists"
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
first_lba=34 #$(echo "$sfdisk_output" | grep 'first-lba:' | tr -d ' ' | cut -d ':' -f 2)
last_lba=$(echo "$sfdisk_output" | grep 'last-lba:' | tr -d ' ' | cut -d ':' -f 2)
sector_size=$(echo "$sfdisk_output" | grep 'sector-size:' | tr -d ' ' | cut -d ':' -f 2)
partedList="$(echo "$sfdisk_output" | grep $device.)"
start_sector=$(echo $partedList | gawk '{if ( match ( $0, /start=\W*([0-9]*)(.*)/, a ) ) print a[1] }')
SEEK_SECTOR=$(($start_sector-($FIRST_SECTOR+$SIZE_SECTORS)))
FULL_LBA=$(($last_lba-($SEEK_SECTOR)))

# Create a new disk with an indent of SIZE_DISK
if [ -f ${TMP_DISK} ];then 
	echo "Deleting a $TMP_DISK"
	rm ${TMP_DISK} 
fi

echo "Create a new disk"

SKIP=$(($start_sector/2048)) # We do not read empty blocks at the beginning of the img image
SEEK=$((FIRST_SECTOR/2048+$SIZE_DISK)) # Skip a FIRST_SECTOR+$SIZE_DISK
dd if=$1 of=$TMP_DISK bs=1M seek=$SEEK skip=$SKIP status=progress
dd if=/dev/zero of=$TMP_DISK bs=512 count=$(($first_lba-34)) seek=$(($(du -b "$TMP_DISK" | awk '{print $1}')/512)) # Increases the end of the disk to the size of first-lba
SIZE_IMG=$(($(du -b "$TMP_DISK" | awk '{print $1}')/512))

r34=$(($SIZE_IMG - $FULL_LBA))
if [ $r34 -ne $first_lba ];then
	echo "Error: The size of the new img image is out of bounds by $(($r34-$first_lba)) bytes"
	exit 1
fi

if [ ! -f $TMP_DISK ];then
	echo "Error: failed to create file '${TMP_DISK}'"
	exit 1
fi

# Recalculates indents of existing volumes
i=2
new_partition=""
while IFS= read -r line
do
  new_partition="${new_partition}NewPartition${i} $(echo $line | gawk '{if ( match ( $0, /(.*)(:.*start=)\W*([0-9]*)(.*)/, a ) ) print a[2]a[3]-('$SEEK_SECTOR')a[4]}' )"$'\n'
  i=$(($i+1))
done < <(printf '%s\n' "$partedList")

# Create a new markup
cat <<EOF | sfdisk $TMP_DISK
label: ${label}
label-id: ${label_id}
device: NewPartition
unit: ${unit}
first-lba: ${first_lba}
last-lba: ${FULL_LBA}
sector-size: ${sector_size}

NewPartition1 : start=$FIRST_SECTOR, size=$SIZE_SECTORS, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name="config"
${new_partition}
EOF

sgdisk -ge $TMP_DISK
sgdisk -v $TMP_DISK

# Formatting
LOOPDEV=$(losetup -P --show -f $TMP_DISK)
CONFIG_PART=$(sgdisk -p $LOOPDEV | grep "config" | tail -n 1 | tr -s ' ' | cut -d ' ' -f 2)
mkfs.fat ${LOOPDEV}p${CONFIG_PART}
losetup -d $LOOPDEV

# Replace the original img image
mv $TMP_DISK $1

echo "Done!"
exit 0