SUITE=$1

for deb in $(ls -1 incoming/*.deb 2>/dev/null)
do 
echo including $deb  
reprepro -v -b . -C main includedeb $SUITE $deb   
done 
 
for udeb in $(ls -1 incoming/*.udeb 2>/dev/null)
do
echo including $udeb
reprepro -v -b . -C main includeudeb $SUITE $udeb 
done

for dsc in $(ls -1 incoming/*.dsc 2>/dev/null)
do
echo including $dsc
reprepro -v -b . -C main includedsc $SUITE $dsc || reprepro -S admin -P optional -v -b . -C main includedsc $1 $dsc
done


