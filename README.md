This script builds a Trisquel CD image from scratch.

The script needs 5 parameters (in the shown order):

* Action to do: debootstrap|iso|source|squash|torrent|all
* Architecture to build: i386|amd64
* Distro to build: trisquel|trisquel-mini|trisquel-sugar|triskel
* Codename (of an existing Trisquel release)

Extra parameters:
i18n: Builds a DVD with extra translations
fsf: Builds the FSF membership card image

Example:
    bash makeiso.sh  all amd64 trisquel etiona i18n

Requirements: genisoimage, squashfs-tools, debootstrap, lzma, curl, syslinux

WARNING: this script uses a ramdisk to build the system, so you need roughly 6GB RAM to run it.