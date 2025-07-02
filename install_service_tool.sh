#!/usr/bin/env bash
#
# ==============================================================================
# SCRIPT: install_service_tool
#
# DESCRIPTION: Creates and enables a systemd service to run a program at boot.
#              This tool is for Linux systems with systemd only.
# ==============================================================================

# --- Sourcing the Library ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR/lib/lib_main.sh"


# --- Script-Specific Functions ---
define_arguments() {
    libCmd_add -t switch -f x --long exec -v "execute_mode" -d "false" -m once -u "Enable actual execution. Defaults to dry run."
    libCmd_add -t switch -f h --long help -v "showHelp" -d "false" -m once -u "Display this help message."
    libCmd_add -t value -f p --long program -v "programName" -r y -m once -u "The name or path of the program to install as a service (required)."
}

# --- Main Orchestration Function ---
main() {
    if ! lib_initializeScript "$@"; then
        return 1
    fi

    # Check for Linux/systemd compatibility
    if [[ "$(uname)" != "Linux" ]]; then
        log_error "This script is for Linux (systemd) only. macOS uses launchd."
        return 1
    fi

    # Check for root privileges
    if (( EUID != 0 )); then
        log_error "This script must be run as root or with sudo."
        return 1
    fi

    local programPath
    programPath=$(command -v "$programName")

    if [[ -z "$programPath" ]]; then
        log_error "Program not found in PATH or as a direct path: '$programName'"
        return 1
    fi

    local programBaseName
    programBaseName=$(basename "$programPath")
    local service_file="/etc/systemd/system/${programBaseName}.service"

    log_info "Found program at: $programPath"
    log_info "Creating service file at: $service_file"

    # Use printf to write the entire file cleanly and at once.
    local service_content
    service_content="[Unit]\nDescription=${programBaseName} service\nAfter=network.target\n\n[Service]\nExecStart=${programPath}\nUser=root\nRestart=always\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n"

    # Use runCommand to write the file as root
    runCommand "$g_execution_flag" "$ON_ERR_EXIT" "printf -- '${service_content}' > '${service_file}'"

    log_info "Reloading Systemd daemon, and enabling/starting service..."
    runCommand "$g_execution_flag" "$ON_ERR_EXIT" "systemctl daemon-reload"
    runCommand "$g_execution_flag" "$ON_ERR_EXIT" "systemctl enable '${programBaseName}.service'"
    runCommand "$g_execution_flag" "$ON_ERR_EXIT" "systemctl start '${programBaseName}.service'"

    log_instr "✅ Service '${programBaseName}.service' created and started successfully."
}

# --- Main Execution Guard ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
