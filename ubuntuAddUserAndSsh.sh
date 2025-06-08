#!/usr/local/bin/bash
#
# This script should be run as root or sudo


thisFile="ubuntuAddUserSetupSsh.sh"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi


# Defining Colors for text output
declare red=$( tput setaf 1 );
declare yellow=$( tput setaf 3 );
declare green=$( tput setaf 2 );
declare normal=$( tput sgr 0 );

# Functions
install_ssh() {
    apt-get update
    apt-get install -y openssh-server
    systemctl enable ssh
    systemctl start ssh
}

configure_sshd() {
    local todaysDate=$(date +%Y%m%d)

    local ignoreHosts="IgnoreRhosts yes"
    local permitRootLogin="PermitRootLogin no"
    local pwAuthenticate="PasswordAuthentication no"
    local disableForwarding="DisableForwarding yes"

    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.${todaysDate}

    egrep "^${disableForwarding}" /etc/ssh/sshd_config 2>&1 > /dev/null
    if [ ${?} -ne 0 ]; then
        echo "
# Disabling all forwarding.
# [note] This setting overrides all other forwarding settings!
# This entry was added by first-ten.sh
DisableForwarding yes" | sudo tee -a /etc/ssh/sshd_config

        echo "${yellow}-> Set \"${disableForwarding}\" in /etc/ssh/sshd_config"
    fi

    egrep "^${ignoreHosts}" /etc/ssh/sshd_config 2>&1 > /dev/null
    if [ ${?} -ne 0 ]; then
        sudo sed -i.bak -e 's/#IgnoreRhosts/IgnoreRhosts/' -e 's/IgnoreRhosts\s\no/IgnoreRhosts\s\yes/' /etc/ssh/sshd_config
        echo "${yellow}-> Set \"${ignoreHosts}\" in /etc/ssh/sshd_config"
    fi

    egrep "^${permitRootLogin}" /etc/ssh/sshd_config 2>&1 > /dev/null
    if [ ${?} -ne 0 ]; then
        sudo sed -i.bak1 '/^PermitRootLogin/s/yes/no/' /etc/ssh/sshd_config
        echo "${yellow}-> Set \"${permitRootLogin}\" in /etc/ssh/sshd_config"
    fi

    egrep "^${pwAuthenticate}" /etc/ssh/sshd_config 2>&1 > /dev/null
    if [ ${?} -ne 0 ]; then
        sudo sed -i.bak2 '/^PasswordAuthentication/s/yes/no/' /etc/ssh/sshd_config
        echo "${yellow}-> Set \"${pwAuthenticate}\" in /etc/ssh/sshd_config"
    fi

    # Restarting ssh daemon
    echo "${yellow}Reloading ssh ${normal}"
    sudo systemctl reload sshd

    echo "${green}ssh has been restarted.  ${normal}"

    #Pause so user can see output
    sleep 1
    systemctl restart sshd
}

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

# Operations
define_operations() {
    add_operation "installSSH" true "--installSSH" "\t--installSSH\tInstall and enable SSH server" "install_ssh"
    add_operation "configureSSHD" true "--configureSSHD" "\t--configureSSHD\tConfigure and secure SSH server" "configure_sshd"
}

# Main
main() {
}


# Main
main ${args[@]}
