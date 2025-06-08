#!/usr/local/bin/bash

# This script first checks if it's running as `root` or with `sudo` privileges. 
# Then it gets the program name from the command line argument and checks if it 
# exists in the current working directory or in the PATH. If the program is found, 
# it creates a Systemd service file for the program in the `/etc/systemd/system/` 
# directory and populates it with the necessary information. Finally, it reloads 
# the Systemd daemon to recognize the new service, enables and starts the service.
# 
# You can run this script with the command `sudo sh script_name.sh program_name` 
# and it will create a systemd service and run the `program_name` on boot.

# Check for existence of bashLibrary_base.sh in this order: current working directory, 
# home directory and PATH.
lib_path="./bashLibrary_base.sh"
[[ -f "$lib_path" ]] || lib_path="$HOME/bashLibrary_base.sh"
[[ -f "$lib_path" ]] || lib_path=$(which bashLibrary_base.sh)
[[ -f "$lib_path" ]] || { echo "${Color_Warning}bashLibrary_base.sh not found.${Color_Reset}" ; }
source "$lib_path"


# Get program name from command line argument
program=${1}
programPath=${program}

# Check if program name was provided
if [[ -z "${program}" ]]
then
    echo "${Color_Error}Please provide a program name.${Color_Reset}"
    exit 1
fi

# Check if program exists in current working directory
programPath=$(getProgramPath ${program})
program=$(basename ${programPath})

# Create Systemd service file
service_file="/etc/systemd/system/${program}.service"
# touch "${service_file}"
run_command "exit" touch ${service_file}

# Populate service file with program information
echo "[Unit]" >> "${service_file}"
echo "Description=${program} service" >> "${service_file}"
echo "After=network.target" >> "${service_file}"
echo "" >> "${service_file}"
echo "[Service]" >> "${service_file}"
echo "ExecStart=${program_path}" >> "${service_file}"
echo "User=root" >> "${service_file}"
echo "Restart=always" >> "${service_file}"
echo "RestartSec=5" >> "${service_file}"
echo "" >> "${service_file}"
echo "[Install]" >> "${service_file}"
echo "WantedBy=multi-user.target" >> "${service_file}"

# Reload Systemd daemon to recognize new service
systemctl daemon-reload

# Enable and start the new service
systemctl enable "${program}.service"
systemctl start "${program}.service"

echo "${Cyan}Service ${program}.service created and started successfully.${Color_Reset}"

