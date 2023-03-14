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

export TRACKER=http://tracker.trisquel.org:6969/announce

export MKTORRENT="../files/mktorrent-1.0/mktorrent"

SEEDS=$(for i in $MIRRORS
do
	echo -n $i$FILE','
done | sed 's/,$//')

VERSION=9.0.2
CODENAME=etiona

$MKTORRENT -a $TRACKER -c "Trisquel GNU/Linux $VERSION $CODENAME Network Installer" -w $SEEDS $1
md5sum $1 > $1.md5
sha1sum $1 > $1.sha1
sha256sum $1 > $1.sha256
