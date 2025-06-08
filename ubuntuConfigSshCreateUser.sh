#!/usr/local/bin/bash
# This script should be run as root.

thisFile="${BASH_SOURCE[0]}"
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi

# # ****************************************************
# {{{ @name: add_operation <name> <default_install> <flag> <usage> <function_name>
# *
# * Add package spec to array variable $packages
# ****************************************************
add_operation() {
    if [ -z "${operations}" ]; then declare -A -g packages; fi

    local name=$1
    local default_install=$2
    local flag=$3
    local usage=$4
    local function_name=$5
    local install="$default_install"

    local -i numPkgs=${#operations[@]}

    #for package in "${operations[@]}"; do
    # echo "Echo: operations[$numPkgs]=$name:$default_install:$install:$flag:$usage:$function_name"
    operations[$numPkgs]="$name:$default_install:$install:$flag:$usage:$function_name"

    # Verify that the provided function_name matches an existing function
    if [ ! command -v "$function_name" &> /dev/null ]; then
        echo "Error: no matching function exists: ${function_name}"
        exit 1
    fi

}
# }}}
# ****************************************************

# # ****************************************************
# {{{ @name: install_ssh
# *
# * 
# ****************************************************
install_ssh() {
    apt-get update
    apt-get install -y openssh-server
    systemctl enable ssh
    systemctl start ssh
}
# }}}
# ****************************************************

# # ****************************************************
# {{{ @name: configure_sshd
# *
# * 
# ****************************************************
configure_sshd() {
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
    systemctl restart sshd
}
# }}}
# ****************************************************

# # ****************************************************
# {{{ @name: create_user <username> <sshKey>
# *
# * 
# ****************************************************
create_user() {
    local user="$1"
    local ssh_key="$2"

    adduser --gecos "" "$user"
    usermod -aG sudo "$user"

    mkdir -p "/home/$user/.ssh"
    echo "$ssh_key" > "/home/$user/.ssh/authorized_keys"
    chmod 600 "/home/$user/.ssh/authorized_keys"
    chown -R "$user:$user" "/home/$user/.ssh"
}
# }}}
# ****************************************************

# # ****************************************************
# {{{ @name: define_operations
# *
# * Add package spec to array variable $packages
# ****************************************************
define_operations() {
    add_operation "installSSH" true "--installSSH" "\t--installSSH\tInstall and enable SSH server" "install_ssh"
    add_operation "configureSSHD" true "--configureSSHD" "\t--configureSSHD\tConfigure and secure SSH server" "configure_sshd"
}
# }}}
# ****************************************************

parse_arguments "${args[@]}"
execute_operations

