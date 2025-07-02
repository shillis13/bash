#!/usr/local/bin/bash
# set -x

# fail fast and explicitly
set -euo pipefail

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi
thisFile="${BASH_SOURCE[0]}"

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

########################
## Script: 
##      - Create user USERNAME and add to sudoers
##      - Create ssh for USERNAME and add key(s) in OTHER_PUBLIC_KEYS_TO_ADD
##      - Disable root SSH login with password
########################

# *******************************************************************
# * {{{ SCRIPT VARIABLES 
# *
# *******************************************************************
# Name of the user to create and grant sudo privileges
USERNAME=joeytess13

# Name of the users home directory - this will get set by the script
HOME_DIR=""

# Whether to copy over the root user's `authorized_keys` file to the new sudo
# user.
COPY_AUTHORIZED_KEYS_FROM_ROOT=false

# Additional public keys files to add for the new user
OTHER_PUBLIC_KEYS_FILES_TO_ADD=(
    
)

# Additional public keys to add for the new user
# OTHER_PUBLIC_KEYS_TO_ADD=(
#     "ssh-rsa AAAAB..."
#     "ssh-rsa AAAAB..."
# )
OTHER_PUBLIC_KEYS_TO_ADD=(
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvF8zGMMRCOtfv6qRAbhjO0jPvlwCJxlw/9qsItpzFc joeytess13@gmail.com
)
# }}}
# *******************************************************************

####################
### SCRIPT LOGIC ###
####################

# *******************************************************************
# * {{{ disableRootSshLogin()
# * 
# *******************************************************************
# *******************************************************************
fcns[i++]="disableRootSshLogin"
usages[i]="-s|--disableRootSshLogin"
disableRootSshLogin() {
    # Disable root SSH login with password
    sed --in-place 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
    if sshd -t -q; then
        systemctl restart sshd
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ disableRootPwLogin() 
# * 
# *******************************************************************
fcns[i++]="disableRootPwLogin"
usages[i]="-p|--disableRootPwLogin"
disableRootPwLogin() {
    # Check whether the root account has a real password set
    encrypted_root_pw="$(grep root /etc/shadow | cut --delimiter=: --fields=2)"

    if [ "${encrypted_root_pw}" != "*" ]; then
        # Transfer auto-generated root password to user if present
        # and lock the root account to password-based access
        echo "${USERNAME}:${encrypted_root_pw}" | chpasswd --encrypted
        passwd --lock root
    else
        # Delete invalid password for user if using keys so that a new password
        # can be set without providing a previous value
        passwd --delete "${USERNAME}"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ setupUser
# * 
# *******************************************************************
fcns[i++]="setupUser"
usages[i]="-u|--setupUser"
setupUser() {
    # Add user and grant privileges
    useradd --create-home --shell "/bin/bash" --groups sudo "${USERNAME}"

    # Expire the user's password immediately to force a change
    change --lastday 0 "${USERNAME}"

    # Create SSH directory for user
    HOME_DIR="$(eval echo ~${USERNAME})"
    mkdir --parents "${HOME_DIR}/.ssh"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ copyRootSshKeys() 
# * 
# *******************************************************************
fcns[i++]="copyRootSshKeys"
usages[i]="-c|--copyRootSshKeys"
copyRootSshKeys() {
    # Copy `authorized_keys` file from root if requested
    if [ "${COPY_AUTHORIZED_KEYS_FROM_ROOT}" = true ]; then
        cp /root/.ssh/authorized_keys "${HOME_DIR}/.ssh"
    fi

    # Add additional provided public keys
    for pub_key in "${OTHER_PUBLIC_KEYS_TO_ADD[@]}"; do
        echo "${pub_key}" >> "${HOME_DIR}/.ssh/authorized_keys"
    done

    # Adjust SSH configuration ownership and permissions
    chmod 0700 "${HOME_DIR}/.ssh"
    chmod 0600 "${HOME_DIR}/.ssh/authorized_keys"
    chown --recursive "${USERNAME}":"${USERNAME}" "${HOME_DIR}/.ssh"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ usage
# * Parse the usage info
# *
# ****************************************************
usage() {
    echo "Usage:"
    echo -n "$thisFile "
    for arg in "${usages[@]}"; do
        echo -n "< $arg > "
    done
    echo ""
}
# }}} 
# *******************************************************************

# *******************************************************************
# * {{{ parse_args
# * Parse the command line args 
# *
# ****************************************************
parse_args() {
    while [[ $# -gt 0 ]]
    do
        key="$1"
        case $key in
            -p|--disableRootPwLogin)
                disableRootPwLogin=true
                shift
                ;;
            -s|--disableRootSshLogin)
                disableRootSshLogin=true
                shift
                ;;
            -u|--setUser)
                setUser=true
                shift
                ;;
            -c|--copyRootSshKeys)
                copyRootSshKeys=true
                shift
                ;;
            -h|--help|--usage)
                usage
                exit 0
                ;;
            *)
                # echo "Invalid flag: $1"
                # exit 1
                shift
                ;;
        esac
    done
}
# }}} 
# *******************************************************************
#
# *******************************************************************
# * {{{ main()
# * 
# *******************************************************************
main() {
    if [ $# -gt 0 ]; then
        # Determine if usage or a function was passed on the cmd line
        if [ ! -z "$1" ] && [ "$1" == "usage" ]; then
            usage 
            exit -1
        else
            if [ ! -z "$1" ] && [ "$1" == "usage" ]; then
        fi
    fi
}
# }}}
# *******************************************************************

main ${args[@]}
