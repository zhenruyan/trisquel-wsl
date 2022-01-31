#!/bin/bash
#
#    Copyright (C) 2012-2022  Ruben Rodriguez <ruben@trisquel.info>
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
#PERSISTENCESIZE=500 # Sice of the persistence file, in MB

ISOTMP=$(mktemp -d)
DEVTMP=$(mktemp -d)

umount $DEV* || true
mount -o loop $ISO $ISOTMP

# Create FAT32 LBA partition taking all disk
echo 'start=2048, type=c' | sfdisk $DEV
mkfs.vfat -I -F32 ${DEV}1

# Copy the data
mount ${DEV}1 $DEVTMP
cp -vr $ISOTMP/* $ISOTMP/.disk $DEVTMP || true

mv $DEVTMP/isolinux $DEVTMP/syslinux
mv $DEVTMP/syslinux/isolinux.cfg $DEVTMP/syslinux/syslinux.cfg

# Create persistency file
# dd if=/dev/zero of=$DEVTMP/casper-rw bs=1M count=$PERSISTENCESIZE
# mkfs.ext3 -F $DEVTMP/casper-rw 
# sed '/label live/,/append/s/$/ persistent/' $DEVTMP/syslinux/txt.cfg

umount $DEVTMP

syslinux ${DEV}1
dd conv=notrunc if=/usr/lib/syslinux/mbr/mbr.bin bs=440 count=1 of=$DEV
parted $DEV set 1 boot on
sync

eject $DEV

