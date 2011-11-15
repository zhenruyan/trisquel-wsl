for ARCH in i386 amd64
do

    cp files/initrd.netinst.$ARCH initrd.netinst.$ARCH.gz

    gunzip -f initrd.netinst.$ARCH.gz
    lzma -9 initrd.netinst.$ARCH
    mv initrd.netinst.$ARCH.lzma initrd.netinst.$ARCH
done  
