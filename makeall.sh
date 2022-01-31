#!/bin/bash
#
#    Copyright (C) 2022 Ruben Rodriguez <ruben@trisquel.info>
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

if [ $UID != 0 ]; then
    echo You need to run this script as root!
    exit 1
fi

CODENAME=etiona
VERSION=9.0.2
MKTORRENT=$PWD/files/mktorrent-1.0/mktorrent
TRACKER=http://tracker.trisquel.org:6969/announce

rm NOT-FOUND source -rf

for arch in amd64 i386; do
  bash makeiso.sh all $arch trisquel $CODENAME i18n
  bash makeiso.sh all $arch triskel $CODENAME
  bash makeiso.sh all $arch trisquel-sugar $CODENAME
  bash makeiso.sh all $arch trisquel-mini $CODENAME
done

#bash makeiso.sh source amd64 trisquel $CODENAME

cd iso
for arch in i686; do
  mv trisquel-netinst_*_$arch.iso trisquel-netinst_${VERSION}_$arch.iso
  md5sum trisquel-netinst_${VERSION}_$arch.iso > trisquel-netinst_${VERSION}_$arch.iso.md5
  sha1sum trisquel-netinst_${VERSION}_$arch.iso > trisquel-netinst_${VERSION}_$arch.iso.sha1
  sha256sum trisquel-netinst_${VERSION}_$arch.iso > trisquel-netinst_${VERSION}_$arch.iso.sha256
done
MIRRORS="https://cdimage.trisquel.org/trisquel-images/
https://mirror.fsf.org/trisquel-images/
https://mirror.math.princeton.edu/pub/trisquel-iso/
https://mirrors.ocf.berkeley.edu/trisquel-images/
https://ftp.acc.umu.se/mirror/trisquel/iso/
https://mirror.linux.pizza/trisquel/images/
https://ftpmirror1.infania.net/mirror/trisquel/iso/
https://mirror.operationtulip.com/trisquel/images/
https://mirror.librelabucm.org/trisquel-images/
https://ftp.caliu.cat/pub/distribucions/trisquel/iso/
https://quantum-mirror.hu/mirrors/pub/trisquel/iso/
https://mirror.cedia.org.ec/trisquel.iso/
https://mirrors.dotsrc.org/trisquel-iso/
https://mirrors.ustc.edu.cn/trisquel-images/
https://mirrors.nju.edu.cn/trisquel-images/
https://mirror.csclub.uwaterloo.ca/trisquel/iso/"
maketorrent(){
    FILE=$1
    DESC=$2
    SEEDS=$(for i in $MIRRORS; do
 	      echo -n ${i}$FILE','
            done | sed 's/,$//')

    $MKTORRENT -a $TRACKER -c "Trisquel GNU/Linux $VERSION $CODENAME $DESC" -w $SEEDS $FILE
}

maketorrent trisquel-netinst_${VERSION}_amd64.iso "Network Installer"
maketorrent trisquel-netinst_${VERSION}_i686.iso "Network Installer"

