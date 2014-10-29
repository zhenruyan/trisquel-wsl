DATE=$(date +%Y%m%d)

for ARCH in i386 amd64
do


cp /home/systems/devel/jails/trusty-$ARCH/root/initrd.gz initrd.netinst.$ARCH.gz

    gunzip -f initrd.netinst.$ARCH.gz
    lzma -9 initrd.netinst.$ARCH
    mv initrd.netinst.$ARCH.lzma initrd.netinst.$ARCH

cp /home/systems/devel/jails/trusty-$ARCH/root/vmlinuz vmlinuz.netinst.$ARCH

[ $ARCH = i386 ] && ARCH=i686

cp /home/systems/devel/jails/trusty-$ARCH/root/mini.iso ../iso/trisquel-netinst_7.0-${DATE}_$ARCH.iso
md5sum ../iso/trisquel-netinst_7.0-${DATE}_$ARCH.iso > ../iso/trisquel-netinst_7.0-${DATE}_$ARCH.iso.md5
gpg -ba ../iso/trisquel-netinst_7.0-${DATE}_$ARCH.iso

done  
