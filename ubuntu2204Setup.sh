#!/usr/local/bin/bash
# set -ex

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi
thisFile="${BASH_SOURCE[0]}"

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

########################
# Lifted a lot from: Ubuntu-server-setup Script from git
# https://github.com/jasonheecs/ubuntu-server-setup
#
########################

# *******************************************************************
# * {{{ Variables
# *
# *******************************************************************

# }}}
# *******************************************************************

# *******************************************************************
# * {{{ includeDependencies() 
# *
# *******************************************************************
includeDependencies() {
    # shellcheck source=./ubuntu2204Setup_Library.sh
    source ubuntu2204Setup_Library.sh
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ ubuntu2204_main() 
# * 
# *******************************************************************
ubuntu2204_main() {
    current_dir=$(getCurrentDir)
    includeDependencies
    output_file="output.log"

    # Run setup functions
    trap cleanup EXIT SIGHUP SIGINT SIGTERM

    defaultUsername=$(whoami)
    username=$(defaultUsername)
    createUpdateUserYN=""

    while [[ $createUpdateUserYN != [nN] ]] && [[ $createUpdateUserYN != [yY] ]]; do
        read -rp "Do you want to create a new non-root user? (Recommended) [Y/N] " createUpdateUserYN

        if [[ $createUpdateUserYN == [yY] ]]; then
            read -rp "Enter the username of the new user account: (default = $defaultUsername)" username
            if [[ $username == "" ]]; then username=$(defaultUsername); fi
            Ul_addUserAccount "${username}"
            Ul_updateUserAccount "${username}"

        elif [[ $createUpdateUserYN == [nN] ]]; then
            createUpdateUserYN=""
            read -rp "Do you want to update an exiting user? [Y/N] " createUpdateUserYN

            if [[ $createUpdateUserYN == [yY] ]]; then
                read -rp "Enter the username of the user account modify: (default = $defaultUsername)" username
                if [[ $username == "" ]]; then username=$(defaultUsername); fi
                Ul_updateUserAccount "${username}"
            fi
        fi
    done

    addSshKeyForUserYN=""

    while [[ $addSshKeyForUserYN!= [nN] ]] && [[ $addSshKeyForUserYN!= [yY] ]]; do
        read -rp "Do you want to add an sshkey for the user ($username)? [Y/N] " addSshKeyForUserYN

        if [[ $addSshKeyForUserYN== [yY] ]]; then
            read -rp $'Paste in the public SSH key for the new user:\n' sshKey
            if [[ $sshkey != "" ]]; then 
                Ul_addSSHKey "${username}" "${sshKey}"
                startTimestampedLog "${output_file}"
                exec 3>&1 >>"${output_file}" 2>&1
            fi

        fi
    done


    Ul_disableSudoPassword "${username}"
    Ul_changeSSHConfig
    Ul_setupUfw
    Ul_setupSwap
    # Ul_setupTimezone

    echo "Configuring System Time... " >&3
    Ul_configureNTP


    echo "Setup Done! Log file is located at ${output_file}" >&3
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ cleanup()
# * 
# *******************************************************************
cleanup() {
    if [[ -f "/etc/sudoers.bak" ]]; then
        Ul_revertSudoers
    fi
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ startTimestampedLog()
# *
# * @param: <filename> 
# *******************************************************************
startTimestampedLog() {
    local filename=${1}
    {
        echo "===================" 
        echo "Log generated on $(date)"
        echo "==================="
    } >>"${filename}" 2>&1
}
# }}} 
# *******************************************************************

ubuntu2204_main ${args[@]}
