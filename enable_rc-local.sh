#!/usr/local/bin/bash

# =====================
# USE AT YOUR OWN RISK.
# =====================
#
# Script to enable the rc-local service
# Creates files:
#	/etc/rc.local
#	/etc/systemd/system/rc-local.service
#
# Created by joeytess13 on 2022-12-23
#

dir="/etc"
file=""

if [ $(echo $(whoami)) != 'root' ]; then
    echo "This script must be run as root"
    exit 1
fi

systemctl status rc-local | grep "inactive (dead)" > /dev/null 2>&1
if [ $? != 0 ]; then
    echo "Verify that rc.local isn't already configured."
    systemctl status rc-local
    
    exit 1
fi

# Create /etc/rc.local
file="$dir/rc.local"
if [ -f "$file" ]; then
    echo "$file already exists"
else
    touch "$file"
    echo "#!/bin/bash" >> "$file"
    echo "" >> "$file"
    echo "exit 0" >> "$file"

    chmod +x "$file"

    # Verify file created
    if [ -f "$file" ]; then
        echo "Created $file"
    else
        echo "Error: $file not created"
        exit 1
    fi
fi

# Create /etc/systemd/system/rc-local.service
dir="/etc/systemd/system"
file="$dir/rc-local.service"
if [ -f "$file" ]; then
    echo "$file already exists"
else
    touch "$file"
    echo "[Unit]" >> $file
    echo "Description=/etc/rc.local Compatibility" >> "$file"
    echo "ConditionPathExists=/etc/rc.local" >> "$file"
    echo "" >> "$file"
    echo "[Service]" >> "$file"
    echo "Type=forking" >> "$file"
    echo "ExecStart=/etc/rc.local start" >> "$file"
    echo "TimeoutSec=0" >> "$file"
    echo "StandardOutput=tty" >> "$file"
    echo "RemainAfterExit=yes" >> "$file"
    echo "SysVStartPriority=99" >> "$file"
    echo "" >> "$file"
    echo "[Install]" >> "$file"
    echo "WantedBy=multi-user.target" >> "$file"

    # Verify file created
    if [ -f "$file" ]; then
        echo "Created $file"
    else
        echo "Error: $file not created"
        exit 1
    fi
fi

# Enable and start rc-local service
systemctl enable rc-local 
systemctl start rc-local.service


# Verify rc-local service is enabled
systemctl status rc-local | grep "active (running)" > /dev/null 2>&1
if [ $? == 0 ]; then
    echo "Error: service rc-local is not running"
    systemctl status rc-local
    
    exit 1
else
    exit 0
fi


