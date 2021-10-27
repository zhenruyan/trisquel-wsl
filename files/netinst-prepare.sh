#!/bin/bash
#
#    Copyright (C) 2011-2020 Ruben Rodriguez <ruben@trisquel.info>
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

cd files || true

DATE=$(date +%Y%m%d)
VERSION=$1
RELEASE=$(echo $1 |sed 's/.*+//;s/trisquel.*//')
DEB_INST_IMAGE="https://builds.trisquel.org/debian-installer-images/"

# True if $1 is greater than $2
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

if [ $# -ne 1 ]; then
  echo Usage: $0 netinst-version
  exit 1
fi

if version_gt "$RELEASE" 9.0 ; then
VALID_ARCH="amd64"
IMAGES="legacy-images"
else
VALID_ARCH="i386 amd64"
IMAGES="images"
fi

for ARCH in $VALID_ARCH
do
LATEST_DATE=$(curl -s $DEB_INST_IMAGE|grep +$RELEASE|grep $ARCH|awk -F ' ' '{print$7,$8}'|sort -r|head -n1)
LATEST_TAR=$(curl -s $DEB_INST_IMAGE|grep +$RELEASE|grep $ARCH|grep "$LATEST_DATE"|awk -F'"' '{print$6}')
wget -q $DEB_INST_IMAGE$LATEST_TAR
tar --wildcards -zxvf  $LATEST_TAR  "./installer-$ARCH/*/$IMAGES/netboot/ubuntu-installer/*/initrd.gz" -O > initrd.netinst.$ARCH.gz

gunzip -f initrd.netinst.$ARCH.gz
lzma -9 initrd.netinst.$ARCH
mv initrd.netinst.$ARCH.lzma initrd.netinst.$ARCH

tar --wildcards -zxvf  $LATEST_TAR  "./installer-$ARCH/*/$IMAGES/cdrom/vmlinuz" -O > vmlinuz.netinst.$ARCH

tar --wildcards -zxvf  $LATEST_TAR  "./installer-$ARCH/*/$IMAGES/netboot/mini.iso" -O > ../iso/trisquel-netinst_$RELEASE-${DATE}_$ARCH.iso

rm $LATEST_TAR

if [ $ARCH = i386 ] ; then
 mv ../iso/trisquel-netinst_$RELEASE-${DATE}_$ARCH.iso ../iso/trisquel-netinst_$RELEASE-${DATE}_i686.iso
 ARCH=i686
fi

done  
