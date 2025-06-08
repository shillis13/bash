#!/usr/local/bin/bash

logFile="~/serverStats.log"

fractSec=$(echo "scale=2; (`date +%N` / 1000000000)"  | bc -s)
date=`date +"%a %F %T"`$fractSec

systemctl status snap.rocketchat-server.rocketchat-server
systemctl status snap.rocketchat-server.rocketchat-mongo


logMsg="$date : Load Limit ($loadLimit) exceeded : load1 = $load1Txt and load2 = $load2Txt on $host"

