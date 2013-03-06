#!/bin/sh
#
# script to list mozilla common files
#

. /etc/slitaz/cook.conf

. $WOK/thunderbird/receipt

cd $WOK/$PACKAGE/install/usr/lib/$PACKAGE-$VERSION
for file in $(find $PWD -type f); do
	file1="$file"
	file2="$(echo "$file" | sed 's/thunderbird/firefox/g')"
	diff $file1 $file2 >/dev/null 2>/dev/null
	[ "$?" = "0" ] && ls -l "$file"
done
exit 0
