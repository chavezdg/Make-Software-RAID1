#!/usr/bin/env bash

deviceList=$( lsblk -d | grep "sd" | awk '{ print $1 }' | cut -c 3 )
mntDevs=$( grep -o "/dev/sd[a-z]" /proc/mounts | awk '{ print $1 }' | sort -u | cut -c 8 )
allDevs=()
allDevs+=( ${deviceList[@]} ${mntDevs[@]} )
devNoMnt=$( echo "${allDevs[@]}" | tr ' ' '\n' | sort | uniq -u )

function wipeDrivePart1(){
fdisk /dev/sd"$driveNameChar" << EOF
d
w
EOF
}

function wipeDrivePart2(){
fdisk /dev/sd"$driveNameChar" << EOF
d

d
w
EOF
}

clear
echo ""
echo " ~ MAKE SOFTWARE RAID 1 ~"
echo " -- Version 1.0 --"
echo ""
echo "...CHECKING AVAILABLE DEVICES"
echo ""

for dev in $devNoMnt; do
 lsblk -n /dev/sd"$dev"
 echo ""
done

echo "SELECT PRIMARY AND SECONDARY AVAILABLE DEVICES"
echo "FOR EXAMPLE, PRIMARY DEVICE \"sdb\" WOULD BE \"b\""
echo "AND SECONDARY DEVICE \"sdc\" WOULD BE \"c\""
echo "..."
read -p "SELECT PRIMARY DEVICE: " primaryDev
read -p "SELECT SECONDARY DEVICE: " secndryDev

if [[ "$primaryDev" == "$secndryDev" ]]; then
 echo "SELECTED DEVICES CANNOT BE THE SAME"
 exit 0
fi

echo "CREATING GNU/LINUX PARTITIONS"
part1Count=$( lsblk -n /dev/sd"$primaryDev" | wc -l )
part2Count=$( lsblk -n /dev/sd"$secndryDev" | wc -l )
driveNameChar=""

case $part1Count in
 2) driveNameChar="$primaryDev"
    wipeDrivePart1
    driveNameChar=""
 ;;
 3) driveNameChar="$primaryDev"
    wipeDrivePart2
    driveNameChar=""
 ;;
esac

case $part2Count in
 2) driveNameChar="$secndryDev"
    wipeDrivePart1
    driveNameChar=""
 ;;
 3) driveNameChar="$secndryDev"
    wipeDrivePart2
    driveNameChar=""
 ;;
esac

parted -a optimal /dev/sd"$primaryDev" <<EOF
mklabel msdos
unit MiB
mkpart primary 1MiB -1MiB
print
quit
EOF

echo "FORMATTING TO EXT4"
mkfs.ext4 /dev/sd${primaryDev}1
echo "CREATING IDENTICAL PARTITION"
sfdisk -d /dev/sd"$primaryDev" | sfdisk -f /dev/sd"$secndryDev"
echo "LOADING KERNEL MODULES"
modprobe linear
modprobe raid0
modprobe raid1
cat /proc/mdstat
echo "GENERATING RAID"
mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sd${primaryDev}1 missing <<EOF
y
EOF
cat /proc/mdstat
echo "CREATING MDADM CONF FILE"
mdadm --detail --scan > /etc/mdadm.conf
cat /etc/mdadm.conf
echo "CREATING SOFTWARE RAID FILE SYSTEMS"
mkfs.ext4 /dev/md0
echo "ADDING SELECTED PARITION TO SOFTWARE RAID"
mdadm /dev/md0 --add /dev/sd${secndryDev}1
echo "SOFTWARE RAID INSTALL STATUS:"
cat /proc/mdstat


