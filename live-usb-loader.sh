#!/bin/bash
#
#    Copyright (C) 2012  Ruben Rodriguez <ruben@trisquel.info>
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


umount $DEV*
mount -o loop $ISO $ISOTMP
mkfs.vfat -I -F32 $DEV
sync
#mount -o sync $DEV $DEVTMP
mount $DEV $DEVTMP
cp -vr $ISOTMP/* $ISOTMP/.disk $DEVTMP
sync

dd if=/dev/zero of=$DEVTMP/casper-rw bs=1M count=$PERSISTENCESIZE
mkfs.ext3 -F $DEVTMP/casper-rw 
sync

mv $DEVTMP/isolinux $DEVTMP/syslinux
mv $DEVTMP/syslinux/isolinux.cfg $DEVTMP/syslinux/syslinux.cfg

sync
umount $DEVTMP
syslinux $DEV
sync

eject $DEV

# Did we sync already?
sync
