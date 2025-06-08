#!/usr/local/bin/bash

# =====================
# USE AT YOUR OWN RISK.
# =====================

# This script can be used in crontab, rc5 (/etc/init.d), service, or execute directly.
# It's just a temp fix to this annoying problem, you have to run it on every boot of the system.

# Related to:
# https://github.com/RocketChat/Rocket.Chat/issues/14562

# Created By Majunko.
# Updated by joeytess13 to add mountinfo 

file=/var/lib/snapd/apparmor/profiles/snap.rocketchat-server.rocketchat-mongo
file_new="$file.new"
filelines=$(cat $file)

if [ $(echo $(whoami)) != 'root' ]; then
    echo "This script must be run as root"
    exit 1
fi

declare -i IS_ON_MISC
declare -i i
IS_ON_MISC=0
i=0

while IFS= read -r line; do
    i=$i+1
    # echo $line
    echo $line | grep "# Miscellaneous accesses" > /dev/null 2>&1
    if [ $? == 0 ]; then
        IS_ON_MISC=1
    fi

    if [ $IS_ON_MISC == 1 ] && [ "$line" == "" ]; then

        grep "@{PROC}/@{pid}/net/snmp" $file > /dev/null 2>&1
        if [ $? != 0 ]; then
            awk -v n=$i -v s="  @{PROC}/@{pid}/net/snmp r," 'NR == n {print s} {print}' $file >$file_new
            echo "Added: @{PROC}/@{pid}/net/snmp r,"
            cat $file_new > $file
            i=$i+1
        fi

        grep "@{PROC}/@{pid}/net/netstat" $file > /dev/null 2>&1
        if [ $? != 0 ]; then
            awk -v n=$i -v s="  @{PROC}/@{pid}/net/netstat r," 'NR == n {print s} {print}' $file >$file_new
            echo "Added: @{PROC}/@{pid}/net/netstat r,"
            cat $file_new > $file
        fi
        
        grep "@{PROC}/vmstat" $file > /dev/null 2>&1
        if [ $? != 0 ]; then
            awk -v n=$i -v s="  @{PROC}/vmstat r," 'NR == n {print s} {print}' $file >$file_new
            echo "Added: @{PROC}/vmstat r,"
            cat $file_new > $file
        fi

        grep "@{PROC}/@{pid}/mountinfo" $file > /dev/null 2>&1
        if [ $? != 0 ]; then
            awk -v n=$i -v s="  @{PROC}/@{pid}/mountinfo r," 'NR == n {print s} {print}' $file >$file_new
            echo "Added: @{PROC}/@{pid}/mountinfo r,"
            cat $file_new > $file
        fi
        
        
        if [ -f $file_new ]; then
            rm $file_new
            apparmor_parser -r $file
        else
            echo "AppArmor already configured for RocketChat"
        fi

        break
    fi

done < "$file"
