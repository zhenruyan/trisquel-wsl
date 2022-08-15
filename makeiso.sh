#!/bin/bash
#
#    Copyright (C) 2004-2022 Ruben Rodriguez <ruben@trisquel.info>
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

# True if $1 is greater than $2
version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

export TRACKER=http://tracker.trisquel.org:6969/announce
export MIRRORS="https://cdimage.trisquel.org/trisquel-images/
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
export MIRROR="http://archive.trisquel.org/trisquel/" # The upstream full repository
export MKTORRENT=$PWD/"files/mktorrent-1.0/mktorrent"
#Add proxy support only if proxy variable is specified.
#Example: PROXY_FULL_ADDRESS="user:password@proxy.example.com:3128"
export PROXY_FULL_ADDRESS=""

usage(){
echo "Trisquel iso build script

Copyright (C) 2004-2020  Ruben Rodriguez <ruben@trisquel.info>
License GPLv2+: GNU GPL version 2 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

This script builds a Trisquel CD image from scratch.

The script needs 5 parameters (in the shown order):

* Action to do: debootstrap|iso|source|squash|torrent|all
* Architecture to build: i386|amd64
* Distro to build: trisquel|trisquel-mini|trisquel-sugar|triskel
* Codename (of an existing Trisquel release)

Extra parameters:
i18n: Builds a DVD with extra translations
fsf: Builds the FSF membership card image

Usage: $0 debootstrap|iso|squash|source|torrent|all i386|amd64 trisquel|trisquel-mini|trisquel-sugar|triskel codename [i18n] [fsf]
Requirements: xorriso, squashfs-tools, debootstrap, lzma, wget, syslinux

WARNING: this version of $0 uses a ramdisk to build the system, so you need roughly 6GB RAM to run it."
}

case $1 in
debootstrap|iso|squash|source|all|torrent)     export ACTION=$1
                ;;
*)              usage
                exit 1
                ;;
esac

case $2 in
i386|amd64)	export ARCH=$2
		;;
*)              usage
		exit 1
		;;
esac

case $3 in
trisquel|trisquel-mini|trisquel-sugar|triskel)	export DIST=$3
		;;
*)              usage
		exit 1
		;;
esac

export CODENAME=$4
[ $CODENAME = nabia ] && UPSTREAM=focal && MVER=10.0 && VERSION=10.0.1
[ $CODENAME = etiona ] && UPSTREAM=bionic && MVER=9.0 && VERSION=9.0.2
[ $CODENAME = flidas ] && UPSTREAM=xenial && VERSION=8.0

echo $* | grep -q i18n && i18n=true || i18n=false
# Make a FSF membercard image?
if echo $* | grep -q fsf
then
    i18n=true
    fsf=true
else
    fsf=false
fi

export WORKDIR=$PWD
export DEBIAN_FRONTEND=noninteractive
export CHROOT=$PWD/$DIST-$ARCH
export C="chroot $CHROOT"
export LOG=logs/$DIST-$ARCH.log
export LANG=C
export LC_ALL=C
export LANGUAGE=C

[ -d logs ] || mkdir logs
[ -d iso ] || mkdir iso
[ -f $LOG ] && mv $LOG ${LOG}.old

DO_SOURCE(){

cat << EOF > /etc/apt/sources.list
deb $MIRROR $CODENAME main
deb $MIRROR $CODENAME-updates main
deb $MIRROR $CODENAME-security main
deb-src $MIRROR $CODENAME main
deb-src $MIRROR $CODENAME-updates main
deb-src $MIRROR $CODENAME-security main
EOF

apt-get update
#rm -rf source
#mkdir source
cd source

MANIFESTS=../iso/*manifest
$fsf && MANIFESTS=../iso/*fsf*manifest
$fsf && VERSION=${VERSION}fsf

for i in $(cut -d" " -f1 $MANIFESTS |sort -u); do
i=$(echo $i| sed 's/:.*//')
source=$(apt-cache showsrc $i | head -n 1 | grep '^Package: ' | awk '{print $2}')
    echo "Package: $i (source: $source)"
    [ -f ${source}_*dsc ] && continue || true
    apt-get source -d $source || echo $i:$source >> ../NOT-FOUND
done

# Some shy packages may need to be asked directly
apt-get source -d linux-libc-dev linux-meta memtest86+ syslinux \
                  python-extras efibootmgr shim grub2 plymouth

for file in $(find . -type f|sed 's_./__'); do
 letter=${file:0:1}
 [ -d $letter ] ||  mkdir $letter
 mv $file $letter/$file
done

cd ..
xorriso -as mkisofs -f -J  -joliet-long -r  -V "trisquel-$VERSION src" -o iso/trisquel_${VERSION}_sources.iso source

SEEDS=$(for i in $MIRRORS
do
echo -n ${i}trisquel_${VERSION}_sources.iso','
done | sed 's/,$//')

cd iso
rm -f trisquel_${VERSION}_sources.iso.torrent
$MKTORRENT -a $TRACKER -c "Trisquel GNU/Linux $VERSION $CODENAME Source DVD" -w $SEEDS trisquel_${VERSION}_sources.iso
md5sum trisquel_${VERSION}_sources.iso > trisquel_${VERSION}_sources.iso.md5
sha1sum trisquel_${VERSION}_sources.iso > trisquel_${VERSION}_sources.iso.sha1
sha256sum trisquel_${VERSION}_sources.iso > trisquel_${VERSION}_sources.iso.sha256

}

DELETE_CHROOT() {
if [ -d $1 ]
then
    echo "Umounting and removing $1"
    fuser -k $1 || true
    for MOUNT in $1/proc $1/sys $1/dev/pts $1/tmp $1
    do
        umount $MOUNT || true
    done
rm -rf $1
fi
}

DO_DEBOOTSTRAP() {
## Provided that you run it in a updated trisquel server, debootrstraps a live/installable CD

date
echo "DIST=$DIST
ARCH=$ARCH
CHROOT=$CHROOT
-------------------------------------------------------------------------
-------------------------------------------------------------------------
"

rm -rf master
cp -a files/master-template master
mkdir master/casper
sed -i 's/FOREGROUND/84B0FF/g' master/isolinux/stdmenu.cfg master/isolinux/gfxboot.cfg
echo "Trisquel $VERSION \"$CODENAME\" - Release $ARCH ($(date +%Y%m%d))" | sed s/i386/i686/g > master/.disk/info
echo https://trisquel.info/wiki/$CODENAME > master/.disk/release_notes_url
touch master/.disk/base_installable
echo 'full_cd/single' > master/.disk/cd_type

TXTCFG=files/$DIST.cfg
cp $TXTCFG master/isolinux/txt.cfg

DELETE_CHROOT $CHROOT

# debootstrab the base system
mkdir $CHROOT
#[ $i18n = "false" ] && mount -t tmpfs none -o size=2500M $CHROOT
mount -t tmpfs none -o size=16000M $CHROOT

#use proxy only if proxy variable is set
[ -n "$PROXY_FULL_ADDRESS" ] && \
export http_proxy=$PROXY_FULL_ADDRESS
debootstrap --arch=$ARCH $CODENAME $CHROOT $MIRROR

echo exit 101 > $CHROOT/usr/sbin/policy-rc.d
chmod +x $CHROOT/usr/sbin/policy-rc.d

# Development build key
#wget https://builds.trisquel.org/repos/signkey.asc -O $CHROOT/tmp/key.asc
#$C apt-key add /tmp/key.asc
#rm $CHROOT/tmp/key.asc

#use proxy only if proxy variable is set
[ -n "$PROXY_FULL_ADDRESS" ] && \
echo "Acquire::http::Proxy \"http://$PROXY_FULL_ADDRESS/\";" > $CHROOT/etc/apt/apt.conf.d/proxy.conf
# apt setup for the debootstrap second stage
cat << EOF > $CHROOT/etc/apt/sources.list
deb $MIRROR $CODENAME main
deb $MIRROR $CODENAME-updates main
deb $MIRROR $CODENAME-security main
#deb http://builds.trisquel.org/repos/$CODENAME/ $CODENAME main
#deb http://builds.trisquel.org/repos/$CODENAME/ $CODENAME-security main
#deb http://builds.trisquel.org/repos/$CODENAME/ $CODENAME-updates main
#deb http://builds.trisquel.org/repos/$CODENAME/ $CODENAME-backports main
EOF

$C apt-get update

# prepare the chroot for installing extra packages
mount -t proc none $CHROOT/proc
mount -t devpts none $CHROOT/dev/pts
mount -t sysfs none $CHROOT/sys
mount -t tmpfs none $CHROOT/tmp
echo "127.0.0.1 localhost" > $CHROOT/etc/hosts

#Setup local EFI repository
EFI_LOCAL_REPO="http://builds.trisquel.org/efi"
DISTRO_REPO=$(curl -s $EFI_LOCAL_REPO/|grep $CODENAME|awk -F'"' '{print$6}')

#Get and copy repo to master
wget -q $EFI_LOCAL_REPO/$DISTRO_REPO
rm -rf master/{dists,pool}
tar -zxvf $DISTRO_REPO  --directory master/
rm $DISTRO_REPO

KERNEL=linux-generic

# package install
echo "KERNEL=$KERNEL" > $CHROOT/tmp/install
echo "DIST=$DIST" >> $CHROOT/tmp/install
echo "VERSION=$VERSION" >> $CHROOT/tmp/install
echo 'LANG=C
apt-get update
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends $KERNEL trisquel-minimal trisquel-base
apt-get clean
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends $DIST
aptitude unmarkauto $(apt-cache depends $DIST | grep Depends | sed s/.*:.//)
apt-get clean
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends ${DIST}-recommended spice-vdagent
aptitude unmarkauto $(apt-cache depends $DIST-recommended | grep Depends | sed s/.*:.//)
apt-get clean
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends trisquel-base-recommended
aptitude unmarkauto $(apt-cache depends trisquel-base-recommended | grep Depends | sed s/.*:.//)
apt-get clean
[ $DIST != trisquel-sugar ] && \
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends trisquel-desktop-common-recommended
aptitude unmarkauto $(apt-cache depends trisquel-desktop-common-recommended | grep Depends | sed s/.*:.//)
apt-get clean
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends $(apt-cache show $DIST | grep ^Suggests|sed s/Suggests://|sed s/\,//g|head -n1)
[ $MVER = 9.0 ] && \
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends  xorg xserver-xorg xserver-xorg-input-all xserver-xorg-video-all mesa-vdpau-drivers va-driver-all vdpau-driver-all vdpau-va-driver  casper grub-pc gparted language-pack-en language-pack-es language-pack-gnome-en language-pack-gnome-es hyphen-en-us mythes-en-us lupin-casper abrowser-locale-es aspell aspell-en aspell-es dictionaries-common language-pack-en-base language-pack-gnome-en-base wamerican wbritish wspanish plymouth-theme-trisquel-text plymouth-theme-trisquel-logo gnome-brave-icon-theme
[ $MVER = 10.0 ] && \
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends  xorg xserver-xorg xserver-xorg-input-all xserver-xorg-video-all mesa-vdpau-drivers va-driver-all vdpau-driver-all casper grub-pc gparted language-pack-en language-pack-es language-pack-gnome-en language-pack-gnome-es hyphen-en-us mythes-en-us lupin-casper abrowser-locale-es aspell aspell-en aspell-es dictionaries-common language-pack-en-base language-pack-gnome-en-base wamerican wbritish wspanish plymouth-theme-trisquel-text plymouth-theme-trisquel-logo gnome-brave-icon-theme


apt-get clean
' >> $CHROOT/tmp/install

TOINSTALL=""

LANGSUPPORT="en es pt fr sv de it uk zh-hans ru pl nl ja zh-hant gl ca da hu cs nb fi et el sr sl sk ro bg eu ko nn lt vi pa lv ar he th ga id hi ta eo ast tr oc nds sq km hr tl"
EXTRAPACKAGES="language-pack language-pack-gnome libreoffice-help libreoffice-l10n abrowser-locale gimp-help hunspell icedove-locale"
[ $fsf = "true" ] && EXTRAPACKAGES="abrowser-locale hunspell language-pack language-pack-gnome libreoffice-l10n icedove-locale"
[ $DIST = "trisquel-sugar" ] && EXTRAPACKAGES="language-pack"

if [ $DIST = "triskel" ]; then
  echo "apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages gconf2 ubiquity ubiquity-slideshow-trisquel ubiquity-frontend-kde" >> $CHROOT/tmp/install
else
  echo "apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages gconf2 ubiquity ubiquity-slideshow-trisquel ubiquity-frontend-gtk" >> $CHROOT/tmp/install
fi

if [ $i18n = "true" ]
then
    echo "Making an i18n image"
    for language in $LANGSUPPORT
    do
        for package in $EXTRAPACKAGES
        do
          [ $package = abrowser-locale-en ] && continue
          grep -q "^Package: ${package}-${language}$" $CHROOT/var/lib/apt/lists/*Packages && TOINSTALL+=" ${package}-${language} "
        done
    done
    echo "apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages --no-install-recommends $TOINSTALL" >> $CHROOT/tmp/install
    echo "apt-get clean" >> $CHROOT/tmp/install
    echo $LANGSUPPORT | sed 's/ /\n/g; s/zh-hans/zh_CN/g; s/zh-hant/zh_TW/g; s/pt/pt_PT/g;' |sort -u > master/isolinux/langlist
else
    echo -e "en\nes" > master/isolinux/langlist
fi

[ $DIST = "trisquel" ] && echo "apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages libreoffice-l10n-en-za libreoffice-l10n-en-gb libreoffice-help-en-gb mythes-en-au hunspell-en-za hyphen-en-gb hunspell-en-ca hunspell-en-au hunspell-en-gb gimp-help-common gimp-help-en gimp-help-es hunspell-en-us hunspell-en-gb hunspell-en-za myspell-es openoffice.org-hyphenation icedove-locale-es-es" >> $CHROOT/tmp/install
[ $DIST = "triskel" ] && echo "apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages sddm" >> $CHROOT/tmp/install
[ $fsf = "true" ] && echo "apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages abrowser" >> $CHROOT/tmp/install

echo "apt-get --allow-downgrades --allow-remove-essential --allow-change-held-packages -y dist-upgrade --no-install-recommends" >> $CHROOT/tmp/install
echo "apt-get clean" >> $CHROOT/tmp/install
echo "touch /tmp/finished" >> $CHROOT/tmp/install

#Note that using -e will make any package configuration failing exit without any notice.
$C bash -x -e /tmp/install
rm $CHROOT/tmp/finished

#use proxy only if proxy variable is set
[ -n "$PROXY_FULL_ADDRESS" ] && \
echo "Acquire::http::Proxy \"http://$PROXY_FULL_ADDRESS/\";" > $CHROOT/etc/apt/apt.conf.d/proxy.conf

cat << EOF > $CHROOT/etc/apt/sources.list
# Trisquel repositories for supported software and updates

deb http://archive.trisquel.org/trisquel $CODENAME main
#deb-src https://archive.trisquel.org/trisquel $CODENAME main

deb http://archive.trisquel.org/trisquel $CODENAME-updates main
#deb-src https://archive.trisquel.org/trisquel $CODENAME-updates main

deb http://archive.trisquel.org/trisquel $CODENAME-security main
#deb-src https://archive.trisquel.org/trisquel $CODENAME-security main

#deb http://archive.trisquel.org/trisquel $CODENAME-backports main
#deb-src https://archive.trisquel.org/trisquel $CODENAME-backports main
EOF

## POST-CONFIGURATION ########################################################

[ -d $CHROOT/etc/NetworkManager/conf.d ] && touch $CHROOT/etc/NetworkManager/conf.d/10-globally-managed-devices.conf

cp files/partman-recipe $CHROOT/lib/partman/recipes/20trisquel
[ $DIST = "trisquel" ] && sed -i 's/3000 5000 15000/8000 10000 20000/' $CHROOT/lib/partman/recipes/20trisquel
[ $DIST = "triskel" ] && sed -i 's/3000 5000 15000/8000 10000 20000/' $CHROOT/lib/partman/recipes/20trisquel

##############################################################################

## Casper ##
cat << EOF > $CHROOT/etc/casper.conf
export USERNAME="trisquel"
export USERFULLNAME="trisquel"
export HOST="trisquel"
export BUILD_SYSTEM="Ubuntu"
EOF

mkdir -p $CHROOT/etc/skel/.local/share

$fsf && cp files/fsf master/fsf -a
cp files/artwork/$CODENAME/back.jpg master/isolinux/back.jpg
$fsf && cp files/artwork/$CODENAME/back-fsf.jpg master/isolinux/back.jpg
[ $DIST = trisquel-sugar ] && cp files/artwork/sugar/back-sugar.jpg master/isolinux/back.jpg

# Update master/isolinux/bootlogo
BLTMP=$(mktemp -d)
cp master/isolinux/bootlogo $BLTMP
(cd $BLTMP; cpio -id < bootlogo)
cp master/isolinux/* $BLTMP
rm $BLTMP/bootlogo
(cd $BLTMP; ls | cpio -o > /tmp/bootlogo)
mv /tmp/bootlogo master/isolinux/bootlogo

##############################################################################

## Hardware ID's ##
$C update-pciids
# update-usbids deprecated after etiona 9.0
version_gt "$VERSION" 9.0 || $C update-usbids
##############################################################################

echo "-- CLEANING UP ---------------------------------------------------------------"

umount $CHROOT/proc
umount $CHROOT/dev/pts
umount $CHROOT/sys

# Finish proxy use
[ -n $PROXY_FULL_ADDRESS ] && \
rm $CHROOT/etc/apt/apt.conf.d/proxy.conf && \
unset http_proxy

$C apt-get update
$C apt-get clean
$C apt-get autoclean

[ -f  $CHROOT/usr/lib/locale/locale-archive ] && rm -v $CHROOT/usr/lib/locale/locale-archive
$C locale-gen en_US.UTF-8
[ $DIST = trisquel-sugar ]  && $C update-locale LANG=en_US.UTF-8

rm -rf $CHROOT/var/cache/apt-xapian-index/*
##############################################################################
#Launch prepare netinstall iso and components for larger isos.
bash files/netinst-prepare.sh $MVER

[ $DIST = 'trisquel-sugar' ] && echo "background=/usr/share/plymouth/themes/sugar/sugar.png"  >> $CHROOT/etc/lightdm/lightdm-gtk-greeter.conf
[ $DIST = 'trisquel-sugar' ] && echo -e "[Seat:*]\nuser-session=sugar"  >> $CHROOT/etc/lightdm/lightdm.conf.d/sugar.conf

echo "Running custom script for $DIST"
[ -x files/scripts/$DIST ] && files/scripts/$DIST
[ $fsf = "true" ] && files/scripts/fsf
echo "Done running custom scripts"

$C update-gconf-defaults || true

## INITRD ####################################################################
$C update-initramfs -u
##############################################################################

# a bit of cleaning

umount $CHROOT/tmp/
find $CHROOT |grep [.-]old$ | xargs -r rm -v
find $CHROOT |grep [.-]bak$ | xargs -r rm -v

for dir in $CHROOT/var/lib/update-notifier/user.d/ $CHROOT/var/lib/apt-xapian-index/
do
    [ -d $dir ] || continue
    find $dir -type f |xargs -r rm
done

$C chown _apt.root -R /var/lib/apt/lists

## Hosts ##
echo "" > $CHROOT/etc/hosts
##############################################################################

#update the kernel image in the master dir
INITRD=$( basename $DIST-$ARCH/boot/initrd.img-* )
NEW_UUID=$(uuidgen -r)

if [ $MVER = 10.0 ]; then
#mkdir -p $CHROOT/tmp/uninitrd
#unmkinitramfs $CHROOT/boot/${INITRD} $CHROOT/tmp/uninitrd
#echo $NEW_UUID | tee $CHROOT/tmp/uninitrd/conf/uuid.conf
#$C cd /tmp/uninitrd/ && \
#$C find . 2>/dev/null | cpio --quiet -R 0:0 --reproducible -o -H newc | lz4 -9 -l  > /boot/initrd.lz4
#file $CHROOT/boot/initrd.lz4
#rm -r $CHROOT/tmp/uninitrd
# -- seems like none is required to boot ^^
echo $NEW_UUID | tee $CHROOT/boot/casper-uuid-generic
mv $CHROOT/boot/${INITRD} master/casper/initrd
fi


if [ $MVER = 9.0 ]; then
cp  $CHROOT/boot/$INITRD $CHROOT/tmp/initrd.gz && \
$C /sbin/casper-new-uuid /tmp/initrd.gz /boot/initrd.gz /boot/casper-uuid-generic && \
rm $CHROOT/tmp/initrd.gz && \
mv $DIST-$ARCH/boot/${INITRD} master/casper/initrd
fi

mv -v $DIST-$ARCH/boot/vmlinuz-* master/casper/vmlinuz

mv $(find $DIST-$ARCH/ -name casper-uuid-generic) master/.disk

fuser -k -9 $DIST-$ARCH || true

# Ugly hack to fix a problem with the live image FS access
echo "chmod 644 /usr/lib/locale/locale-archive" >> $CHROOT/usr/sbin/locale-gen

echo Debootstrap completed succesfully

}

DO_TORRENT(){

[ $ARCH = "i386" ] &&  ARCH=i686

FILE=${DIST}_${VERSION}_${ARCH}.iso
#[ $i18n = "true" ] && FILE=${DIST}_${VERSION}-i18n_${ARCH}.iso
[ $fsf = "true" ] && FILE=${DIST}_${VERSION}-fsf_${ARCH}.iso

[ $DIST != "trisquel" ] && EXTRACOMMENT=", $DIST edition"

SEEDS=$(for i in $MIRRORS
do
echo -n $i$FILE','
done | sed 's/,$//')

cd iso
rm $FILE.torrent -rf
$MKTORRENT -a $TRACKER -c "Trisquel GNU/Linux $VERSION $CODENAME$EXTRACOMMENT. $ARCH Installable Live DVD" -w $SEEDS $FILE
}

DO_ISO(){
# builds the CD iso image using the squashfs compressed filesystem

cd master
find casper -type f | xargs md5sum > md5sum.txt
cd $WORKDIR

[ $ARCH = "i386" ] && SUBARCH=i686 || SUBARCH=amd64

#VERSION=$VERSION-$(date +%Y%m%d)

NAME=${DIST}_${VERSION}_$SUBARCH

[ $fsf = "true" ] &&  NAME=${DIST}_${VERSION}-fsf_$SUBARCH

find master -type f | xargs chmod 644
find master -type d | xargs chmod 755

if [ $ARCH = "amd64" ] ; then
  mkdir -p master/EFI/BOOT
  cp files/EFI/BOOT/* master/EFI/BOOT
  xorriso -as mkisofs    -l -J -R -V "${DIST} ${VERSION} ${SUBARCH}" -A "${DIST} ${VERSION} ${SUBARCH}"  -no-emul-boot -boot-load-size 4 -boot-info-table    -b isolinux/isolinux.bin -c isolinux/boot.cat    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin    -eltorito-alt-boot -e EFI/BOOT/efi.img -no-emul-boot -isohybrid-gpt-basdat -o iso/${NAME}.iso master
else
  xorriso -as mkisofs    -l -J -R -V "${DIST} ${VERSION} ${SUBARCH}" -A "${DIST} ${VERSION} ${SUBARCH}"  -no-emul-boot -boot-load-size 4 -boot-info-table    -b isolinux/isolinux.bin -c isolinux/boot.cat    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -no-emul-boot -isohybrid-gpt-basdat -o iso/${NAME}.iso master
fi

cp master/casper/filesystem.manifest iso/${NAME}.iso.manifest
cd iso
md5sum ${NAME}.iso > ${NAME}.iso.md5
sha1sum ${NAME}.iso > ${NAME}.iso.sha1
sha256sum ${NAME}.iso > ${NAME}.iso.sha256
rm -f ${NAME}.iso.asc
cd ..

# take one down, and pass it around
[ -f logs/counter ] || echo 0 > logs/counter
expr $(cat logs/counter) + 1 > logs/counter
}

DO_SQUASH (){
# creates the squashfs.filesystem compressed image
[ -f master/casper/filesystem.squashfs ] && rm master/casper/filesystem.squashfs
mksquashfs  $DIST-$ARCH master/casper/filesystem.squashfs -comp lzo -b 16384

chmod 644  master/casper/filesystem.squashfs
$C dpkg -l|grep ^ii |awk '{print $2" "$3}' > master/casper/filesystem.manifest
df -B 1 $CHROOT |tail -n1|awk '{print $3}' > master/casper/filesystem.size
[ $i18n = "true" ] && du -bc $CHROOT |tail -n 1|cut  -f1 > master/casper/filesystem.size

for i in ubiquity language-pack language-support hunspell myspell libreoffice-hyphenation libreoffice-thesaurus rdate localechooser-data casper user-setup gparted libdebconfclient0 libdebian-installer libreoffice-help gimp-help
do
grep $i master/casper/filesystem.manifest >> master/casper/filesystem.manifest-remove || true
done

}

ACTION(){
export COLUMNS=500

case $ACTION in
debootstrap)	DO_DEBOOTSTRAP
		;;
iso)		DO_ISO
		;;
torrent)	DO_TORRENT
		;;
squash)		DO_SQUASH
		DO_ISO
		;;
source)		DO_SOURCE
		;;
all)		DO_DEBOOTSTRAP
		DO_SQUASH
		DO_ISO
		DO_TORRENT
		DELETE_CHROOT $CHROOT
		;;
esac
}

trap 'catch $? $LINENO' EXIT
catch() {
  if [ "$1" != "0" ]; then
    DELETE_CHROOT $CHROOT
    echo "Error $1 occurred on $2"
  fi
}

ACTION 2>&1 3>&1 |tee $LOG

echo finished
