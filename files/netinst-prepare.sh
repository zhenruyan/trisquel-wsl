for ARCH in i386 amd64
do


cp /home/systems/devel/jails/precise-$ARCH/root/initrd.gz initrd.netinst.$ARCH.gz

    gunzip -f initrd.netinst.$ARCH.gz
    lzma -9 initrd.netinst.$ARCH
    mv initrd.netinst.$ARCH.lzma initrd.netinst.$ARCH
done  
