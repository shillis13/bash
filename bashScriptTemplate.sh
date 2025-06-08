#!/usr/local/bin/bash
# set -x

thisFile="${BASH_SOURCE[0]}"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi

source bashLibrary_base.sh "${args[@]}"
source ubuntu2204Setup_Library.sh "${args[@]}"

##################################
# Script:
#   Parameter flags to optionally:
#   - Install Chrome
#   - Install Visual Studio code
#   - Install ssh
#   - Install docker
#   - Install autojump
#   - Install sysstat
#   - Install shellcheck
#   
##################################

# *******************************************************************
# * {{{ define_variables_uSwInstall() 
# *
# * @desc: define packages
# *******************************************************************
define_variables_uSwInstall() {
    add_package "shellcheck" true "--shellcheck" "\t--shellcheck\tinstall shellcheck" "install_shellcheck"
    add_package "sysstat" true "--sysstat" "\t--sysstat\tinstall sysstat" "install_sysstat"
    add_package "autojump" true "--autojump" "\t--autojump\tinstall autojump" "install_autojump"
    add_package "ssh" true "--ssh" "\t--ssh\tinstall ssh" "install_ssh"
    add_package "docker" true "--docker" "\t--docker\tinstall docker" "install_docker"
    add_package "chrome" false "--chrome" "\t--chrome\tinstall chrome" "install_chrome"
    add_package "vscode" false "--vscode" "\t--vscode\tinstall vscode" "install_vscode"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ main
# *
# *******************************************************************
main() {
    local args=("$@")
    define_variables_uSwInstall

    MyUser=$(whoami)
    theDate=$(date +%y-%m-%d_%H:%M:%S)
    tmpDir="/tmp/${MyUser}_${theDate}"

    NOT="${Color_Warning}NOT${Color_Reset}"

    parse_args_for_run_command "${args[@]}"
    parse_pkg_args "${args[@]}"

    checkSudoOrRoot

    run_command mkdir -p $tmpDir
    run_command cd $tmpDir

    run_packages

    if [ -z $cleanUp ]; then run_command \rm -rf $tmpDir; fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ parse_args_uSwInstall() 
# *
# * @desc: Parse command-line flags
# *******************************************************************
parse_args_uSwInstall() {
    while [[ $# -gt 0 ]]
    do
        key="$1"
	shift
    done
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ install_chrome
# *
# *******************************************************************
install_chrome() {
    if ! [ -x "$(command -v google-chrome)" ]; then
        run_command echo "${Color_Info}Installing Google Chrome.${Color_Reset}"
        run_command wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        run_command dpkg -i google-chrome-stable_current_amd64.deb
    else
        run_command echo "${Color_Warning}Google Chrome is already installed.${Color_Reset}"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ install_vscode() {
# *
# *******************************************************************
install_vscode() {
    if ! [ -x "$(command -v code)" ]; then
        run_command echo "${Color_Info}Installing VS Code.${Color_Reset}"
        run_command wget "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" --output-document vscode.deb
        run_command dpkg -i vscode.deb
    else
        run_command echo "${Color_Warning}VS Code is already installed.${Color_Reset}"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ install_ssh() {
# *
# *******************************************************************
install_ssh() {
    if ! [ -x "$(command -v sshd)" ]; then
        run_command echo "${Color_Info}Installing openssh-server.${Color_Reset}"
        run_command apt install -y openssh-server
        run_command systemctl enable ssh
        run_command systemctl start ssh
        run_command echo "${Color_Info}Run ssh-keygen as your user after installation.${Color_Reset}"
    else
        run_command echo "${Color_Warning}openssh-server is already installed.${Color_Reset}"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ install_docker() 
# *
# *******************************************************************
install_docker() {
    if ! [ -x "$(command -v docker)" ]; then
        run_command echo "${Color_Info}Installing Docker.${Color_Reset}"
        run_command apt install -y ca-certificates curl gnupg lsb-release
        run_command mkdir -p /etc/apt/keyrings
        run_command curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        run_command echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
        run_command chmod a+r /etc/apt/keyrings/docker.gpg
        run_command apt update
        run_command apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        run_command groupadd docker
        run_command usermod -aG docker $MyUser
        run_command systemctl enable docker
        run_command systemctl start docker
        run_command echo "${Color_Success}You might logout or restart for docker group to take effect.${Color_Reset}"
    else
        run_command echo "${Color_Warning}Docker is already installed.${Color_Reset}"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ install_autojump() 
# *
# *******************************************************************
install_autojump() {
    if ! [ -x "$(command -v autojump)" ]; then
        run_command echo "${Color_Info}Installing autojump.${Color_Reset}"
        run_command apt install autojump
        run_command echo "# Setup autojump" >> /home/$MyUser/.bashrc
        run_command echo "[[ -s /usr/share/autojump/autojump.sh ]] && source /usr/share/autojump/autojump.sh" >> /home/$MyUser/.bashrc
    else
        run_command echo "${Color_Warning}Autojump is already installed.${Color_Reset}"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ install_shellcheck() 
# *
# *******************************************************************
install_shellcheck() {
    if ! [ -x "$(command -v shellcheck)" ]; then
        run_command echo "${Color_Info}Installing shellcheck.${Color_Reset}"
        run_command sudo apt-get -y install shellcheck
    else
        run_command echo "${Color_Warning}Shellcheck is already installed.${Color_Reset}"
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ install_sysstat()
# *
# *******************************************************************
install_sysstat() {
    # check if sar is already installed
    if ! [ -x "$(command -v sar)" ]; then
        # install sar
        run_command apt-get install -y sysstat
    else
        run_command echo "${Color_Warning}Systat is already installed.${Color_Reset}"
    fi

    # check if the sysstat cron file exists
    if [ -f /etc/cron.d/sysstat ]; then
        toInstallInCron="*/2 * * * * root /usr/lib/sa/sa1 2 1" 
        currentCron=$(egrep "sa1 1 1" /etc/cron.d/sysstat 2>/dev/null)
        currentCron=$(echo $currentCron | sed -r 's/\s+/ /g') # Remove excess whitespace

        if [ $toInstallInCron != $currentCron ]; then
            # comment out the existing sa1 1 1 line
            run_command sed -i 's/^\(.*sa1 1 1.*\)$/#\1/' /etc/cron.d/sysstat
            # add the new line to run sar every 2 seconds
            run_command echo "*/2 * * * * root /usr/lib/sa/sa1 2 1" >> /etc/cron.d/sysstat
        else
            run_command echo "${Color_Warning}cron.d for sysstat is already configured for sar.${Color_Reset}"
        fi
    else
        # create the sysstat cron file and add the new line
        run_command echo "*/2 * * * * root /usr/lib/sa/sa1 2 1" > /etc/cron.d/sysstat
    fi
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ run_command()
# * TODO: Replace with one from bashLibrary
# *******************************************************************
# Conditionally echo/print
run_command() {
    # echo "run_command(${quiet}): $@"
    if [  -z $quiet ]; then 
        if [ -z $dryRun ]; then
            echo "executing: $@"
            $@
        else
            echo "dry-run: $@"
        fi
    else
        if [ -z $dryRun ]; then
            # echo "quietly executing: $@ > /dev/null 2>&1"
            $@ > /dev/null 2>&1 
        # else
            # echo "quietly dry-run: $@ > /dev/null 2>&1"
        fi
    fi
} 
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ usage
# *
# *******************************************************************
usage() {
    echo "Usage: $0 [-a|--all] [-c|--chrome] [-v|--vscode] [-s|--ssh] [-d|--docker] [-a|--autojump]"
    echo "Options:"
    echo " -a, --all Install all."
    echo " -c, --chrome Install Chrome value to true. Default: ${install_chrome}"
    echo " -v, --vscode Install VS Code. Default: false"
    echo " -s, --ssh Install openssh-server. Default: false"
    echo " -d, --docker Install Docker. Default: false"
    echo " -a, --autojump Install Autojump. Default: false"
    echo " -t, --sysstat Install SysStat. Default: false"
    echo " -s, --shellcheck Install shellcheck. Default: false"
    echo " -r, --dryRun Print the commands to install & configure without executing them. Default: false"
    echo " -q, --quiet Supress printouts. Default: False"
    echo " -h, --help Show this help message and exit"
    echo -e "\nNote: this script needs to run as root or with sudo"
}
# }}}
# *******************************************************************

main ${args[@]}


