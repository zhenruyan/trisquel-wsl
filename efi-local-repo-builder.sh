#!/bin/bash
# Script intended to build local efi repositories archives as part of makeiso components.
set -eE -o pipefail

CODENAME=$1
GPG_KEY="C05112F"

[ -z $CODENAME ] && echo "usage: $0 etiona|nabia" && exit
[ -z $GPG_KEY ] && echo "It's required to setup a full GPG key" && exit

[ $CODENAME = "etiona" ] && REL=9.0
[ $CODENAME = "nabia" ] && REL=10.0

[ -f $(which curl) ]
[ -f $(which reprepro) ]
[ -f $(which wget) ]

# setup local apt
LOCAL_APT=`mktemp -d`
trap "rm -rf ${LOCAL_APT}" 0 HUP INT QUIT ILL ABRT FPE SEGV PIPE TERM

mkdir -p ${LOCAL_APT}
touch ${LOCAL_APT}/status
touch ${LOCAL_APT}/trusted.gpg

cat << APT_CONF > ${LOCAL_APT}/apt.conf
Dir::State "${LOCAL_APT}";
Dir::State::status "${LOCAL_APT}/status";
Dir::Etc::SourceList "${LOCAL_APT}/apt.sources.list";
Dir::Etc::SourceParts "";
Dir::Cache "${LOCAL_APT}";
pkgCacheGen::Essential "none";
Dir::Etc::Trusted "${LOCAL_APT}/trusted.gpg";
Acquire::ForceIPv4 "true";
APT_CONF

cat << SOURCES > $LOCAL_APT/apt.sources.list
deb [signed-by=/usr/share/keyrings/trisquel-archive-keyring.gpg] http://archive.trisquel.org/trisquel $CODENAME main
#deb-src [signed-by=/usr/share/keyrings/trisquel-archive-keyring.gpg] http://archive.trisquel.org/trisquel $CODENAME main

deb [signed-by=/usr/share/keyrings/trisquel-archive-keyring.gpg] http://archive.trisquel.org/trisquel $CODENAME-updates main
#deb-src [signed-by=/usr/share/keyrings/trisquel-archive-keyring.gpg] http://archive.trisquel.org/trisquel $CODENAME-updates main

deb [signed-by=/usr/share/keyrings/trisquel-archive-keyring.gpg] http://archive.trisquel.org/trisquel $CODENAME-security main
#deb-src [signed-by=/usr/share/keyrings/trisquel-archive-keyring.gpg] http://archive.trisquel.org/trisquel $CODENAME-security main
SOURCES

echo -e "\n >>>> Getting updated available $CODENAME packages to create repo...\n"
apt-get -q update -c $LOCAL_APT/apt.conf

#Create files
[ -d ${CODENAME}_efi_repo ] && rm -r ${CODENAME}_efi_repo
mkdir -p ${CODENAME}_efi_repo/amd64/{conf,incoming}

#Get packages
apt-get -c $LOCAL_APT/apt.conf \
        --print-uris  install efibootmgr \
                              grub-efi-amd64-bin | \
        cut -d\' -f2|grep http > ${CODENAME}_efi_repo/amd64/incoming/efi_wget.list

wget -q -P ${CODENAME}_efi_repo/amd64/incoming/ -i \
           ${CODENAME}_efi_repo/amd64/incoming/efi_wget.list && \
     rm -r ${CODENAME}_efi_repo/amd64/incoming/efi_wget.list

#Setup repo
cat << REPO > ${CODENAME}_efi_repo/amd64/conf/distributions
# $CODENAME
Origin: Trisquel
Label: Trisquel
Suite: $CODENAME
Version: $REL
Codename: $CODENAME
Architectures: amd64
Components: main
#DDebComponents: main
#DDebIndices: Packages . .gz .bz2
DebIndices: Packages Release . .gz .bz2
DscIndices: Sources Release .gz .bz2
Contents:
Log: $CODENAME.log
Description: Trisquel GNU/Linux packages
Update: $UPSTREAM $CODENAME-packages #$CODENAME-devel $CODENAME-security
SignWith: $GPG_KEY
REPO

cd ${CODENAME}_efi_repo/amd64/

for deb in $(ls -1 incoming/*.deb 2>/dev/null)
do
echo including $deb
reprepro -v -b . -C main includedeb $CODENAME $deb
done

for udeb in $(ls -1 incoming/*.udeb 2>/dev/null)
do
echo including $udeb
reprepro -v -b . -C main includeudeb $CODENAME $udeb
done

for dsc in $(ls -1 incoming/*.dsc 2>/dev/null)
do
echo including $dsc
reprepro -v -b . -C main includedsc $CODENAME $dsc || reprepro -S admin -P optional -v -b . -C main includedsc $CODENAME $dsc
done

tar -czf ${CODENAME}_efi_repo.tar.gz pool dists
mv ${CODENAME}_efi_repo.tar.gz ../../

cd ../../
rm -r ${CODENAME}_efi_repo
