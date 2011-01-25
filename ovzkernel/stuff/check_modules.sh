#!/bin/sh
# Echo any module in kernel .config that's not added to one of linux-* pkgs
# (c) SliTaz - GNU General Public License.
# 20090618 <jozee@slitaz.org> 
# 20100528 <pankso@slitaz.org>
#
if [ -f "./tazwok.conf" ]; then
	. ./tazwok.conf
else 
	. /etc/tazwok.conf
fi

VERSION=`grep  ^VERSION= $WOK/ovzkernel/receipt | cut -d "=" -f2 | sed -e 's/"//g'`
src="$WOK/ovzkernel/ovzkernel-$VERSION"

cd $src
mkdir -p ../stuff/tmp
rm -f ../stuff/tmp/*

echo -e "\nChecking for modules selected in .config but not in ovzkernel-* pkgs"
echo "======================================================================"

# create a packaged modules list
cat ../stuff/modules-"$VERSION".list >> ../stuff/tmp/pkgs-modules-"$VERSION".list 

for i in $(cd $WOK; ls -d ovzkernel-*)
do
	tazpath="taz/$i-$VERSION"
	for j in $(cat $WOK/$i/$tazpath/files.list | grep ".ko.gz")
	do
	echo "$WOK/$i/$tazpath"
		basename $j >> ../stuff/tmp/pkgs-modules-"$VERSION".list	
	done 	
done
# get the original list in .config
for i in $(find $_pkg -iname "*.ko.gz") 
do

	basename $i >> ../stuff/tmp/originial-"$VERSION".list
	echo "$i"
done
# compare original .config and pkged modules
for i in $(cat ../stuff/tmp/originial-$VERSION.list)   
do		
	if ! grep -qs "$i" ../stuff/tmp/pkgs-modules-"$VERSION".list ; then 
		modpath=`find $_pkg -iname "$i"`
		echo "Orphan module: $i"
		echo "$i : $modpath" >> ../stuff/tmp/unpackaged-modules-"$VERSION".list
	fi
done
if [ -f ../stuff/tmp/unpackaged-modules-"$VERSION".list ]; then
	echo "======================================================================"
	echo -e "Check ovzkernel/stuff/tmp/unpackaged-modules-$VERSION.list for mod path\n"
else
	echo -e "\nAll modules are packaged\n"
	echo "======================================================================"
	echo ""
	rm -rf ../stuff/tmp
fi
