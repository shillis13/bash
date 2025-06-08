#!/usr/local/bin/bash
# set -x

######################################
# Ubuntu bash library (Ul)
######################################

thisFile="${BASH_SOURCE[0]}"
# echo "* Echo: Entered $thisFile..."

source bashLibrary_base.sh "${args[@]}"

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

# ****************************************************************************
# From:
#   https://github.com/jasonheecs/ubuntu-server-setup/blob/master/setupLibrary.sh
#   But modified 
#
# Functions:
#   Ul_updateUserAccount
#   Ul_addUserAccount
#   Ul_setupSwap
#   Ul_hasSwap
#   Ul_createSwap
#   Ul_mountSwap
#   Ul_tweakSwapSettings
#   Ul_saveSwapSettings
#   Ul_configureNTP
#   Ul_getPhysicalMemory
#   Ul_disableSudoPassword
#   Ul_revertSudoers
#   Ul_setupTimezone
# ****************************************************************************

# *******************************************************************
# * {{{ Ul_updateUserAccount()
# *
# * @desc: Update the user account
# * @params: <Account Username>
# *
# *******************************************************************
Ul_updateUserAccount() {
    local username=${1}
    
    sudo passwd -d "${username}"
    sudo usermod -aG sudo "${username}"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_updateUserAccount()
# *
# * @desc: Add the new user account
# * @params: <Account Username>
# * @params: [ <Account pw> defaults=username ]
# * @params: [ <quiet flag: true/false> default=false ]
# *
# *******************************************************************
Ul_addUserAccount() {
    local username="${1}"
    local password="${2}"
    local silent_mode="${3}"
    if [ ! -z ${2} ]; then
        if [ "${2}" == true || "${2}" == false ]; then
            password="${username}"
            silent_mode="${2}"
        fi
        if [ -z ${3} ]; then
            silent_mode=false
        fi
    else
        password="${username}"
        silent_mode=false
    fi

    if [[ ${silent_mode} == true ]]; then
        sudo adduser --force-badname --disabled-password --force-badname --gecos '' "${username}"
    else
        sudo adduser --force-badname --disabled-password "${password}"
    fi

    sudo usermod -aG sudo "${username}"
    sudo passwd -d "${password}"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_setupSwap()
# * 
# *******************************************************************
Ul_setupSwap() {
    if [ Ul_hasSwap ]; then 
        Ul_createSwap
        Ul_mountSwap
        Ul_tweakSwapSettings "10" "50"
        Ul_saveSwapSettings "10" "50"
    fi
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ Ul_hasSwap()
# * 
# *******************************************************************
Ul_hasSwap() {
    [[ "$(sudo swapon -s)" == *"/swapfile"* ]]
    return ${?}
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ Ul_createSwap()
# *
# * @desc:  Create the swap file based on amount of physical memory on 
# *         machine (Maximum size of swap is 4GB)
# *******************************************************************
Ul_createSwap() {
   local swapmem=$(($(Ul_getPhysicalMemory) * 2))

   # Anything over 4GB in swap is probably unnecessary as a RAM fallback
   if [ ${swapmem} -gt 4 ]; then
        swapmem=4
   fi

   sudo fallocate -l "${swapmem}G" /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_mountSwap() 
# *
# * @desc: Mount the swapfile
# *******************************************************************
Ul_mountSwap() {
    sudo cp /etc/fstab /etc/fstab.bak
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_tweakSwapSettings() 
# *
# * @desc: Modify the swapfile settings
# * @param: <new vm.swappiness value>
# * @param: <new vm.vfs_cache_pressure value>
# *******************************************************************
Ul_tweakSwapSettings() {
    local swappiness=${1}
    local vfs_cache_pressure=${2}

    sudo sysctl vm.swappiness="${swappiness}"
    sudo sysctl vm.vfs_cache_pressure="${vfs_cache_pressure}"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_saveSwapSettings() 
# *
# * @desc: Save the modified swap settings
# * @param: <new vm.swappiness value>
# * @param: <new vm.vfs_cache_pressure value>
# *******************************************************************
Ul_saveSwapSettings() {
    local swappiness=${1}
    local vfs_cache_pressure=${2}

    echo "vm.swappiness=${swappiness}" | sudo tee -a /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=${vfs_cache_pressure}" | sudo tee -a /etc/sysctl.conf
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_configureNTP() 
# *
# * @desc: Configure Network Time Protocol
# *******************************************************************
Ul_configureNTP() {
    ubuntu_version="$(lsb_release -sr)"
    maxValue=$(max "${ubuntu_version}" 20.04)

    if [[ "${maxValue}" == "${ubuntu_version}" ]]; then
        sudo systemctl restart systemd-timesyncd
    else
        sudo apt-get update
        sudo apt-get --assume-yes install ntp
        
        if Ul_ufwIsRunning; then
            sudo ufw allow ntp
            sudo ufw allow 123/udp
        fi

        # force NTP to sync
        sudo service ntp stop
        sudo ntpd -gq
        sudo service ntp start
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_getPhysicalMemory()
# *
# * @desc: Gets the amount of physical memory in GB (rounded up) installed on the machine
# *******************************************************************
Ul_getPhysicalMemory() {
    local phymem
    phymem="$(free -g|awk '/^Mem:/{print $2}')"
    
    if [[ ${phymem} == '0' ]]; then
        echo 1
    else
        echo "${phymem}"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_disableSudoPassword()
# * 
# * @params: <Account Username>
# * @desc: Disables the sudo password prompt for a user account by editing /etc/sudoers
# *******************************************************************
Ul_disableSudoPassword() {
    local username="${1}"

    sudo cp /etc/sudoers /etc/sudoers.bak
    sudo bash -c "echo '${1} ALL=(ALL) NOPASSWD: ALL' | (EDITOR='tee -a' visudo)"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_revertSudoers() 
# * 
# * @desc: Reverts the original /etc/sudoers file before this script is ran
# *******************************************************************
Ul_revertSudoers() {
    sudo cp /etc/sudoers /etc/sudoers.reverted

    if [ -f /etc/sudoers.bak ]; then
        sudo cp /etc/sudoers.bak /etc/sudoers
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ Ul_setupTimezone()
# * 
# *******************************************************************
Ul_setupTimezone() {
    echo -ne "Enter the timezone for the server (Default is 'Asia/Singapore'):\n" >&3
    read -r timezone
    if [ -z "${timezone}" ]; then
        timezone="Asia/Singapore"
    fi
    
    echo "${timezone}" | sudo tee /etc/timezone
    sudo ln -fs "/usr/share/zoneinfo/${timezone}" /etc/localtime # https://bugs.launchpad.net/ubuntu/+source/tzdata/+bug/1554806
    sudo dpkg-reconfigure -f noninteractive tzdata
    echo "Timezone is set to $(cat /etc/timezone)" >&3
}
# }}} 
# *******************************************************************

