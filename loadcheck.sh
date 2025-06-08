#!/usr/local/bin/bash

alert=support@adultrefuge.com # put your monitor alert email here
tsleep=60       # time to wait in seconds before 2 checks
loadLimit=4.0   # load limit before action
host=`hostname -f`
logFile="/var/log/loadavg.log"

function getLoadAvgs()
{
    local getAllValues=$1
    if [[ $getAllValues != "" ]];
    then
        echo `cat /proc/loadavg | awk {'print $1 " " $2 " " $3'}` # The 1,5,15 min load averages
    else
        echo `cat /proc/loadavg | awk {'print $1'}` # The 1 min load average
    fi
}

load1Val=$(getLoadAvgs)
load1Txt=$(getLoadAvgs "Y")

sleep $tsleep

load2Val=$(getLoadAvgs)
load2Txt=$(getLoadAvgs "Y")

fractSec=$(echo "scale=2; (`date +%N` / 1000000000)"  | bc -s)
date=`date +"%a %F %T"`$fractSec
logMsg="$date : Load Limit ($loadLimit) exceeded : load1 = $load1Txt and load2 = $load2Txt on $host"

if [ "$load1Val" = "$(printf "$load1Val\n$loadLimit\n" | sort -gr | head -1)" ]
then
   echo "$logMsg" >> $logFile

   if [ "$load2Val" = "$(printf "$load2Val\n$load1Val\n" | sort -gr | head -1)" ]
   then
        echo "$logMsg : Restarting RocketChat" | mail -s "$host : High Load Average Alert" $alert
        echo "$logMsg : Restarting RocketChat" >> $logFile

	    systemctl restart snap.rocketchat-server.rocketchat-server
	    systemctl restart snap.rocketchat-server.rocketchat-mongo
    else
        echo "ok" 1>&2
    fi
else                                                                                                                                              
    sleep 1
fi
