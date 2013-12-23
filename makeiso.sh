#!/bin/bash
#
#    Copyright (C) 2004,2005,2006,2007,2008,2009,2010,2011,2012 Rubén Rodríguez <ruben@trisquel.info>
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

if [ $UID != 0 ]; then
    echo You need to run this script as root!
    exit 1
fi

#set -e

export TRACKER=http://trisquel.info:6969/announce
export MIRRORS="http://cdimage.trisquel.info/trisquel-images/ http://us.archive.trisquel.info/iso/ http://es.gnu.org/~ruben/trisquel/"
export MIRROR="http://archive.trisquel.info/trisquel/" # The upsream full repository
export MKTORRENT=$PWD/"files/mktorrent-1.0/mktorrent"

usage(){
echo "Trisquel iso build script

Copyright (C) 2004,2005,2006,2007,2008,2009,2010, 2011  Ruben Rodriguez <ruben@trisquel.info>
License GPLv2+: GNU GPL version 2 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

This script builds a Trisquel CD image from scratch. The \"files\" directory is required.

The script needs 5 parameters (in the shown oeder):

* Action to do: debootstrap|iso|source|squash|torrent|all
* Architecture to build: i386|amd64
* Distro to build: trisquel|trisquel-mini|trisquel-sugar|triskel
* Codename (of an existing Trisquel release)

Extra parameters:
i18n: Builds a DVD with extra translations
fsf: Builds the FSF membership card image

Usage: $0 debootstrap|iso|squash|source|torrent|all i386|amd64 trisquel|trisquel-mini|trisquel-sugar|triskel codename [i18n] [fsf]
Requirements: genisoimage, squashfs-tools, debootstrap, lzma, curl, syslinux

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
export VERSION=$(wget -q -O - http://archive.trisquel.info/trisquel/dists/$CODENAME/Release|grep ^Version:|cut -d" " -f2)
[ $CODENAME = taranis ] && UPSTREAM=lucid
[ $CODENAME = slaine ] && UPSTREAM=maverick
[ $CODENAME = dagda ] && UPSTREAM=natty
[ $CODENAME = brigantia ] && UPSTREAM=oneiric

export LOCALMIRROR="deb http://devel.trisquel.info/trisquel/$CODENAME $CODENAME main" # The optional local testing repository

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
rm -rf source
mkdir source
cd source

for i in $(cut -d" " -f1 ../iso/*manifest |sort -u) 
do
echo $i
    source=$(apt-cache showsrc $i | grep '^Package: ' | awk '{print $2}')
    apt-get source -d $source || echo $i:$source >> ../NOT-FOUND
done

# Some shy packages may need to be asked directly
apt-get source -d linux-libc-dev linux-meta memtest86+ syslinux gnome-python-extras efibootmgr

cd ..
mkisofs -f -J  -joliet-long -r  -V "trisquel-$VERSION src" -o iso/trisquel_${VERSION}_sources.iso source

SEEDS=$(for i in $MIRRORS
do
echo -n ${i}iso/trisquel_${VERSION}_sources.iso','
done | sed 's/,$//')

cd iso
$MKTORRENT -a $TRACKER -c "Trisquel GNU/Linux $VERSION $CODENAME Source DVD" -w $SEEDS trisquel_${VERSION}_sources.iso

}

DELETE_CHROOT() {
if [ -d $1 ]
then
    echo "Umounting and removing $1"
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
sed -i 's/FOREGROUND/84B0FF/g' master/isolinux/stdmenu.cfg master/isolinux/gfxboot.cfg
echo "Trisquel $VERSION \"$CODENAME\" - Release $ARCH ($(date +%Y%m%d))" | sed s/i386/i686/g > master/.disk/info
echo http://trisquel.info/wiki/$CODENAME > master/.disk/release_notes_url

TXTCFG=files/$DIST.cfg
[ $i18n = "true" ] && TXTCFG=files/$DIST-i18n.cfg
cp $TXTCFG master/isolinux/txt.cfg

DELETE_CHROOT $CHROOT

# debootstrab the base system
mkdir $CHROOT
#[ $i18n = "false" ] && mount -t tmpfs none -o size=2500M $CHROOT
mount -t tmpfs none -o size=5000M $CHROOT
debootstrap --arch=$ARCH $CODENAME $CHROOT $MIRROR files/debootstrap

# Disable the service management scripts
SCRIPTS="sbin/start-stop-daemon usr/sbin/invoke-rc.d usr/sbin/service"
for i in $SCRIPTS
do
    mv "$CHROOT/$i" "$CHROOT/$i.REAL"
    cat <<EOF > "$CHROOT/$i"
#!/bin/sh
echo
echo "Warning: Fake /$i called, doing nothing"
EOF
    chmod 755 "$CHROOT/$i"
done

cat <<EOF > "$CHROOT/usr/sbin/start"
#!/bin/sh
echo
echo "Warning: Fake start called, doing nothing"
EOF

cat <<EOF > "$CHROOT/usr/sbin/stop"
#!/bin/sh
echo
echo "Warning: Fake start called, doing nothing"
EOF
chmod 755 $CHROOT/usr/sbin/start $CHROOT/usr/sbin/stop

# apt setup for the debootstrap second stage
cat << EOF > $CHROOT/etc/apt/sources.list
deb $MIRROR $CODENAME main
deb $MIRROR $CODENAME-updates main
deb $MIRROR $CODENAME-security main
$LOCALMIRROR
deb http://ubuntu.activitycentral.com/helpers/repos/precise/ precise main
EOF

# prepare the chroot for installing extra packages
mount -t proc none $CHROOT/proc
mount -t devpts none $CHROOT/dev/pts
mount -t sysfs none $CHROOT/sys
mount -t tmpfs none $CHROOT/tmp
echo "127.0.0.1 localhost" > $CHROOT/etc/hosts

KERNEL=linux-image-generic

# package install
echo "KERNEL=$KERNEL" > $CHROOT/tmp/install
echo "DIST=$DIST" >> $CHROOT/tmp/install
echo 'LANG=C
apt-get update
apt-get install -y --force-yes --no-install-recommends $KERNEL
apt-get clean
apt-get install -y --force-yes --no-install-recommends $DIST
aptitude unmarkauto $(apt-cache depends $DIST | grep Depends | grep -v \| cut -d: -f2)
apt-get clean
apt-get install -y --force-yes --no-install-recommends ${DIST}-recommended
aptitude unmarkauto $(apt-cache depends $DIST-recommended | grep Depends | grep -v \| cut -d: -f2)
apt-get clean
apt-get install -y --force-yes --no-install-recommends trisquel-base-recommended
aptitude unmarkauto $(apt-cache depends trisquel-base-recommended | grep Depends | grep -v \| cut -d: -f2)
apt-get clean
[ $DIST != trisquel-sugar ] && \
apt-get install -y --force-yes --no-install-recommends trisquel-desktop-common-recommended
aptitude unmarkauto $(apt-cache depends trisquel-desktop-common-recommended | grep Depends | grep -v \| cut -d: -f2)
apt-get clean
[ $DIST != trisquel-mini -a $DIST != trisquel-sugar ] && \
apt-get install -y --force-yes --no-install-recommends trisquel-gnome-base-recommended
aptitude unmarkauto $(apt-cache depends trisquel-gnome-base-recommended | grep Depends | grep -v \| cut -d: -f2)
apt-get clean
apt-get install -y --force-yes --no-install-recommends $(apt-cache show $DIST | grep ^Suggests|sed s/Suggests://|sed s/\,//g|head -n1)
apt-get clean
' >> $CHROOT/tmp/install

if [ $i18n = "true" ] 
then
    echo "Making an i18n image"
    LANGSUPPORT="en es pt fr sv de it uk zh-hans ru pl nl ja zh-hant gl ca da hu cs nb fi et el sr sl sk ro bg eu ko nn lt vi pa lv ar he th ga id hi ta eo ast tr oc nds sq km hr"
    for language in $LANGSUPPORT
    do
        for package in language-pack language-pack-gnome libreoffice-help libreoffice-l10n gnome-user-guide abrowser-locale
        do
            echo "apt-get install -y --force-yes --install-recommends ${package}-${language}" >> $CHROOT/tmp/install
            echo "apt-get clean" >> $CHROOT/tmp/install
        done
    done
echo $LANGSUPPORT | sed 's/ /\n/g; s/zh-hans/zh_CN/g; s/zh-hant/zh_TW/g; s/pt/pt_PT/g;' |sort -u > master/isolinux/langlist
else
echo -e "en\nes" > master/isolinux/langlist
fi

if [ $fsf = "true" ]
then
    FSFEXTRAS="inkscape blender mypaint xournal audacity gimp gimp-ufraw"
    echo "apt-get install -y --force-yes --install-recommends $FSFEXTRAS" >> $CHROOT/tmp/install
    echo "aptitude unmarkauto $FSFEXTRAS" >> $CHROOT/tmp/install
    echo "apt-get clean" >> $CHROOT/tmp/install
fi

echo "apt-get --force-yes -y dist-upgrade" >> $CHROOT/tmp/install
echo "apt-get clean" >> $CHROOT/tmp/install

$C sh /tmp/install

## POST-CONFIGURATION ########################################################

# Enable vblank sync, specially for nouveau
cat << EOF > $CHROOT/etc/X11/xorg.conf
Section "Device"
 Identifier "Default"
 Option "GLXVBlank" "on"
EndSection
EOF

[ $i18n = "true" ] && sed -i 's/500 4000 10000/4500 5000 10000/' $CHROOT/lib/partman/recipes/20trisquel
##############################################################################

## Clean packages ##
echo $DIST > $CHROOT/var/lib/debfoster/keepers
##############################################################################

## Casper ##
cat << EOF > $CHROOT/etc/casper.conf
export USERNAME="trisquel"
export USERFULLNAME="trisquel"
export HOST="trisquel"
export BUILD_SYSTEM="Ubuntu"
EOF

rm $CHROOT/usr/share/initramfs-tools/scripts/casper-premount/10driver_updates

mkdir -p $CHROOT/etc/skel/.local/share

[ -d master/fsf ] && rm -rf master/fsf
cp files/artwork/$CODENAME/back.jpg master/isolinux/back.jpg

##############################################################################

## Adduser ##
sed -i 's/#ADD_EXTRA_GROUPS=1/ADD_EXTRA_GROUPS=1/g' $CHROOT/etc/adduser.conf
sed -i 's/DIR_MODE=0755/DIR_MODE=0751/g' $CHROOT/etc/adduser.conf

##############################################################################

## Hardware ID's ##
$C update-pciids
$C update-usbids
##############################################################################

# We can enable the init scripts now
for i in $SCRIPTS
do
    mv "$CHROOT/$i.REAL" "$CHROOT/$i"
done
rm $CHROOT/usr/sbin/start $CHROOT/usr/sbin/stop

echo "-- CLEANING UP ---------------------------------------------------------------"
if [ $DIST != "trisquel-sugar" ]; then
$C apt-get remove -y --force-yes --purge humanity-icon-theme || true
fi

umount $CHROOT/proc
umount $CHROOT/dev/pts
umount $CHROOT/sys
echo "" > $CHROOT/etc/apt/sources.list

## APT ##
cat << EOF > $CHROOT/etc/apt/sources.list
# Trisquel repositories for supported software and updates
deb http://es.archive.trisquel.info/trisquel $CODENAME main
#deb-src http://es.archive.trisquel.info/trisquel $CODENAME main
deb http://es.archive.trisquel.info/trisquel $CODENAME-updates main
#deb-src http://es.archive.trisquel.info/trisquel $CODENAME-updates main
deb http://es.archive.trisquel.info/trisquel $CODENAME-security main
#deb-src http://es.archive.trisquel.info/trisquel $CODENAME-security main
#deb http://es.archive.trisquel.info/trisquel $CODENAME-backports main
#deb-src http://es.archive.trisquel.info/trisquel $CODENAME-backports main
EOF
$C apt-get update
$C apt-get clean
$C apt-get autoclean
rm $CHROOT/var/lib/apt/lists/*Translation*

[ -f  $CHROOT/usr/lib/locale/locale-archive ] && rm -v $CHROOT/usr/lib/locale/locale-archive

rm -rf $CHROOT/var/cache/apt-xapian-index/*
##############################################################################


echo "Running custom script for $DIST"
[ -x files/scripts/$DIST ] && files/scripts/$DIST
[ $fsf = "true" ] && files/scripts/fsf
echo "Done running custom scripts"

$C update-gconf-defaults

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

## Hosts ##
echo "" > $CHROOT/etc/hosts
echo "" > $CHROOT/etc/resolv.conf
rm $CHROOT//etc/resolvconf/resolv.conf.d/original
rm $CHROOT//etc/resolvconf/resolv.conf.d/tail
##############################################################################

#update the kernel image in the master dir
INITRD=$( basename $DIST-$ARCH/boot/initrd.img* )
mv $DIST-$ARCH/boot/$INITRD $DIST-$ARCH/boot/${INITRD}.gz
gunzip $DIST-$ARCH/boot/${INITRD}.gz
lzma -9 $DIST-$ARCH/boot/$INITRD
mv $DIST-$ARCH/boot/${INITRD}.lzma master/casper/initrd

mv -v $DIST-$ARCH/boot/vmlinuz*  master/casper/vmlinuz
echo Debootstrap completed succesfully
}

DO_TORRENT(){

[ $ARCH = "i386" ] &&  ARCH=i686

FILE=${DIST}_${VERSION}_${ARCH}.iso
[ $i18n = "true" ] && FILE=${DIST}_${VERSION}-i18n_${ARCH}.iso
[ $fsf = "true" ] && FILE=${DIST}_${VERSION}-fsf_${ARCH}.iso

[ $DIST != "trisquel" ] && EXTRACOMMENT=", $DIST edition"

SEEDS=$(for i in $MIRRORS
do
echo -n $i$FILE','
done | sed 's/,$//')

cd iso
$MKTORRENT -a $TRACKER -c "Trisquel GNU/Linux $VERSION $CODENAME$EXTRACOMMENT. $ARCH Installable Live CD" -w $SEEDS $FILE
}

DO_ISO(){
# builds the CD iso image using the squashfs compressed filesystem

cd master
find casper -type f | xargs md5sum > md5sum.txt
cd $WORKDIR

[ $ARCH = "i386" ] && SUBARCH=i686 || SUBARCH=amd64

[ $ARCH = "amd64" ] && cp files/EFI master -a

cp files/repo/$ARCH/pool master -a
cp files/repo/$ARCH/dists master -a

#VERSION=$VERSION-$(date +%Y%m%d)

NAME=${DIST}_${VERSION}_$SUBARCH
[ $i18n = "true" ] && NAME=${DIST}_${VERSION}-i18n_$SUBARCH
[ $fsf = "true" ] &&  NAME=${DIST}_${VERSION}-fsf_$SUBARCH
mkisofs -D -r -V "${DIST} ${VERSION} ${SUBARCH}" -cache-inodes -J -l -b isolinux/isolinux.bin \
   -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
   -hide-joliet /pool -hide-joliet /dists -o iso/${NAME}.iso master
isohybrid iso/${NAME}.iso
cp master/casper/filesystem.manifest iso/${NAME}.manifest
cd iso
md5sum ${NAME}.iso > ${NAME}.iso.md5
cd ..

# take one down, and pass it around
[ -f logs/counter ] || echo 0 > logs/counter
expr $(cat logs/counter) + 1 > logs/counter
}

DO_SQUASH (){
# creates the squashfs.filesystem compressed image
[ -f master/casper/filesystem.squashfs ] && rm master/casper/filesystem.squashfs
mksquashfs $DIST-$ARCH master/casper/filesystem.squashfs

chmod 644  master/casper/filesystem.squashfs
$C dpkg -l|grep ^ii |awk '{print $2" "$3}' > master/casper/filesystem.manifest
df -B 1 $CHROOT |tail -n1|awk '{print $3}' > master/casper/filesystem.size
[ $i18n = "true" ] && du -bc $CHROOT |tail -n 1|cut  -f1 > master/casper/filesystem.size

for i in ubiquity language-pack language-support hunspell myspell libreoffice-hyphenation libreoffice-thesaurus rdate localechooser-data casper user-setup gparted libdebconfclient0 libdebian-installer
do
grep $i master/casper/filesystem.manifest >> master/casper/filesystem.manifest-remove
done

}


case $ACTION in
debootstrap)	COLUMNS=500 DO_DEBOOTSTRAP 2>&1 3>&1 0>&1 | COLUMNS=500 tee $LOG
		;;
iso)		COLUMNS=500 DO_ISO 2>&1 3>&1 0>&1 | COLUMNS=500 tee $LOG
		;;
torrent)	COLUMNS=500 DO_TORRENT 2>&1 3>&1 0>&1 | COLUMNS=500 tee $LOG
		;;
squash)		COLUMNS=500 DO_SQUASH 2>&1 3>&1 0>&1 | COLUMNS=500 tee $LOG
		COLUMNS=500 DO_ISO 2>&1 3>&1 0>&1 | COLUMNS=500 tee -a $LOG
		;;
source)		COLUMNS=500 DO_SOURCE 2>&1 3>&1 0>&1 | COLUMNS=500 tee $LOG
		;;
all)		COLUMNS=500 DO_DEBOOTSTRAP 2>&1 3>&1 0>&1 | COLUMNS=500 tee $LOG || exit 1
		COLUMNS=500 DO_SQUASH 2>&1 3>&1 0>&1 | COLUMNS=500 tee -a $LOG
		COLUMNS=500 DO_ISO 2>&1 3>&1 0>&1 | COLUMNS=500 tee -a $LOG
		COLUMNS=500 DO_TORRENT 2>&1 3>&1 0>&1 | COLUMNS=500 tee -a $LOG
		DELETE_CHROOT $CHROOT
		;;
esac




