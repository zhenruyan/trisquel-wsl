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

for ARCH in i386 amd64 ;do

    #initrd
    tar --wildcards -zxvf  /home/pub/debian-installer-images/debian-installer-images_${VERSION}_${ARCH}.tar.gz  "./installer-$ARCH/*/images/netboot/ubuntu-installer/*/initrd.gz" -O > initrd.netinst.$ARCH.gz
    gunzip -f initrd.netinst.$ARCH.gz
    lzma -9 initrd.netinst.$ARCH
    mv initrd.netinst.$ARCH.lzma initrd.netinst.$ARCH

    #vmlinuz
    tar --wildcards -zxvf  /home/pub/debian-installer-images/debian-installer-images_${VERSION}_${ARCH}.tar.gz  "./installer-$ARCH/*/images/cdrom/vmlinuz" -O > vmlinuz.netinst.$ARCH

    #netinst iso
    tar --wildcards -zxvf  /home/pub/debian-installer-images/debian-installer-images_${VERSION}_${ARCH}.tar.gz  "./installer-$ARCH/*/images/netboot/mini.iso" -O > ../iso/trisquel-netinst_8.0-${DATE}_$ARCH.iso
    if [ $ARCH = i386 ] ; then
       mv ../iso/trisquel-netinst_8.0-${DATE}_$ARCH.iso ../iso/trisquel-netinst_8.0-${DATE}_i686.iso
       ARCH=i686
    fi
    md5sum ../iso/trisquel-netinst_8.0-${DATE}_$ARCH.iso > ../iso/trisquel-netinst_8.0-${DATE}_$ARCH.iso.md5

done  
