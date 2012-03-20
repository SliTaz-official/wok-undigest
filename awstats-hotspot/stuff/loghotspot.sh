#!/bin/sh

HOTSPOT="hotspot"
DIRDATA="/var/lib/awstats/$HOTSPOT"

if [ "$1" == "--install" ]; then
	sed -e "s,^LogFile=.*,LogFile=\"$0 < /var/log/squid/access.log |\"," \
	    -e 's/^LogFormat=.*/LogFormat="%code %time4 %bytesd %method %query %host %url"/' \
	    -e "s/^SiteDomain=.*/SiteDomain=\"$HOTSPOT\"/" \
	    -e "s,^DirData=.*,DirData=\"$DIRDATA\"," \
	    -e 's/^LevelForBrowsersDetection=.*/LevelForBrowsersDetection=0/' \
	    -e 's/^LevelForOSDetection=.*/LevelForOSDetection=0/' \
	    -e 's/^LevelForRefererAnalyze=.*/LevelForRefererAnalyze=0/' \
	    -e 's/^LevelForRobotsDetection=.*/LevelForRobotsDetection=0/' \
	    -e 's/^LevelForSearchEnginesDetection=.*/LevelForSearchEnginesDetection=0/' \
	    -e 's/^LevelForKeywordsDetection=.*/LevelForKeywordsDetection=0/' \
	    -e 's/^ShowRobotsStats=.*/ShowRobotsStats=0/' \
	    -e 's/^ShowOSStats=.*/ShowOSStats=0/' \
	    -e 's/^ShowBrowsersStats=.*/ShowBrowsersStats=0/' \
	    -e 's/^ShowOriginStats=.*/ShowOriginStats=0/' \
	    -e 's/^ShowKeyphrasesStats=.*/ShowKeyphrasesStats=0/' \
	    -e 's/^ShowKeywordsStats=.*/ShowKeywordsStats=0/' \
	    -e 's/^ShowMiscStats=.*/ShowMiscStats=0/' \
	    -e 's/^ShowHTTPErrorsStats=.*/ShowHTTPErrorsStats=0/' \
	    < /etc/awstats/awstats.model.conf \
	    > /etc/awstats/awstats.$HOTSPOT.conf
else
	while read time skip1 iprouter skip2 bytesd method query skip3 ; do
		host=$(echo $query | sed 's#.*//\([^/]*\)/.*#\1#')
		#url=$(echo $query | sed 's#.*//[^/]*##')
		url=$(echo $query | sed 's#.*//##')
		echo "200 ${time%.*} $bytesd $method $query $host $url"
	done
fi
