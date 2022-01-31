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

RELEASE=$1
ARCH=$2

if [ $RELEASE != nabia ]; then
  echo Fix VERSION variable
  exit 0
fi
VERSION=10.0
OUTPUT=trisquel-base_${VERSION}_${ARCH}

CHROOT=$(mktemp -d)
mount none $CHROOT -t tmpfs

debootstrap --arch=$ARCH --foreign $RELEASE $CHROOT http://archive.trisquel.info/trisquel

cp /usr/bin/qemu-arm-static $CHROOT/usr/bin

chroot $CHROOT /debootstrap/debootstrap --second-stage

mount -o bind /proc $CHROOT/proc
mount -o bind /dev $CHROOT/dev
mount -o bind /sys $CHROOT/sys

echo "127.0.0.1 localhost" > $CHROOT/etc/hosts

cat << EOF > /etc/apt/sources.list
# See http://trisquel.info/wiki/ for how to upgrade to
# newer versions of the distribution.
deb http://archive.trisquel.org/trisquel/ $RELEASE main
deb-src http://archive.trisquel.info/trisquel/ $RELEASE main
deb http://archive.trisquel.org/trisquel/ $RELEASE-updates main
deb-src http://archive.trisquel.info/trisquel/ $RELEASE-updates main
deb http://archive.trisquel.org/trisquel/ $RELEASE-security main
deb-src http://archive.trisquel.info/trisquel/ $RELEASE-security main
EOF

export DEBIAN_FRONTEND=noninteractive
export LANG=C
export LC_ALL=C
export LANGUAGE=C
chroot $CHROOT apt-get update
chroot $CHROOT apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends linux-generic trisquel-base
chroot $CHROOT apt-get clean

rm $CHROOT/usr/bin/qemu-arm-static
umount $CHROOT/proc
umount $CHROOT/dev
umount $CHROOT/sys

chroot $CHROOT dpkg -l|grep ^ii |awk '{print $2" "$3}' > iso/$OUTPUT.tar.bz2.manifest

tar cjvf iso/$OUTPUT.tar.bz2 -C $CHROOT .
cd iso
md5sum $OUTPUT.tar.bz2 > $OUTPUT.tar.bz2.md5
sha1sum $OUTPUT.tar.bz2 > $OUTPUT.tar.bz2.sha1
sha256sum $OUTPUT.tar.bz2 > $OUTPUT.tar.bz2.sha256

umount $CHROOT
rm $CHROOT -r

echo iso/$OUTPUT.tar.bz2 built successfully
