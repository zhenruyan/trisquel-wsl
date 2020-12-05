#!/bin/bash
#
#    Copyright (C) 2012-2020  Ruben Rodriguez <ruben@trisquel.info>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
#

set -e

usage(){
echo You need to run this script as root
echo Usage: sudo $0 distro.iso /dev/sdX
echo Example: sudo $0 foobar_5.0_i386.iso /dev/sdb
echo
echo WARNING!: this script will delete all data on the whole disk you pass as the second parameter. Make sure it is your USB drive and not your internal hard drive!
echo ANOTHER WARNING!: This script can bite your dog. Use it with care, backup your data.
exit 1
}

[ $(id -u) != 0 ] && usage
[ $# != 2 ] && usage

ISO=$1
DEV=$2
PERSISTENCESIZE=500 # Sice of the persistence file, in MB

ISOTMP=$(mktemp -d)
DEVTMP=$(mktemp -d)

umount $DEV* || true
mount -o loop $ISO $ISOTMP

# Create FAT32 LBA partition taking all disk
echo 'start=2048, type=c' | sfdisk /dev/$DEV
mkfs.vfat -I -F32 ${DEV}1

# Copy the data
mount ${DEV}1 $DEVTMP
cp -vr $ISOTMP/* $ISOTMP/.disk $DEVTMP

mv $DEVTMP/isolinux $DEVTMP/syslinux
mv $DEVTMP/syslinux/isolinux.cfg $DEVTMP/syslinux/syslinux.cfg

# Create persistency file
# dd if=/dev/zero of=$DEVTMP/casper-rw bs=1M count=$PERSISTENCESIZE
# mkfs.ext3 -F $DEVTMP/casper-rw 
# sed '/label live/,/append/s/$/ persistent/' $DEVTMP/syslinux/txt.cfg

umount $DEVTMP

# Set up bootloader, requires syslinux 4x
# http://archive.trisquel.info/trisquel/pool/main/s/syslinux/syslinux-common_4.05+dfsg-6+deb8u1_all.deb
#http://archive.trisquel.info/trisquel/pool/main/s/syslinux/syslinux_4.05+dfsg-6+deb8u1_amd64.deb
syslinux ${DEV}1
dd conv=notrunc if=/usr/lib/syslinux/mbr.bin bs=440 count=1 of=$DEV
parted $DEV set 1 boot on

eject $DEV

