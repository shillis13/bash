#!/usr/bin/env bash
#
# ==============================================================================
# SCRIPT: setup_project.sh
#
# DESCRIPTION: An example script to demonstrate the 'lib' framework.
#              This version uses the lib_main bootstrap function for setup.
# ==============================================================================

# --- Sourcing the Library ---
# Sourcing the main library file, which handles its own dependencies.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR/lib/lib_main.sh"


# ==============================================================================
# Script-Specific Functions
# ==============================================================================

# ------------------------------------------------------------------------------
# Function: define_arguments
#
# This function is REQUIRED by lib_initializeScript. It defines all the
# command-line arguments this specific script accepts.
# ------------------------------------------------------------------------------
define_arguments() {
    log_trace "Defining script-specific arguments..."
    libCmd_add -t switch -f x --long exec -v "execute_mode" -d "false" -m once -u "Enable actual execution. Defaults to dry run."
    libCmd_add -t switch -f h --long help -v "showHelp" -d "false" -m once -u "Display this help message."
    libCmd_add -t value -f n --long name -v "projectName" -r y -m once -u "The name of the new project directory (required)."
    libCmd_add -t value -f g --long git -v "gitRepoUrl" -d "" -m once -u "Optional git repository URL to clone."
    libCmd_add -t switch -f s --long skip-deps -v "skipDeps" -d "false" -m once -u "If set, skips the dependency installation step."
    libCmd_add -t value -f p --long package -v "packages" -m multi -u "A package to add to requirements.txt. Use multiple times."
}

# ------------------------------------------------------------------------------
# These functions contain the core "business logic" of the script.
# ------------------------------------------------------------------------------
handle_directory() {
    local pName="$1"
    local exec_flag="$2"
    log_info "Setting up project directory..."
    runCommand "$exec_flag" "$ON_ERR_EXIT" "mkdir -p \"$pName\""
}

handle_git() {
    local pName="$1"
    local repoUrl="$2"
    local exec_flag="$3"
    if [[ -n "$repoUrl" ]]; then
        log_info "Cloning git repository from $repoUrl..."
        runCommand "$exec_flag" "$ON_ERR_EXIT" "git clone \"$repoUrl\" \"$pName\""
    else
        log_warn "No git repository URL provided. Creating placeholder README."
        runCommand "$exec_flag" "$ON_ERR_EXIT" "touch \"$pName/README.md\""
    fi
}

handle_dependencies() {
    local pName="$1"
    local skip="$2"
    local exec_flag="$3"
    shift 3
    local -a pkgs=("$@")

    if [[ "$skip" == "true" ]]; then
        log_instr "Skipping dependency installation as requested."
        return
    fi

    log_info "Processing dependencies..."
    if (( ${#pkgs[@]} > 0 )); then
        for pkg in "${pkgs[@]}"; do
            runCommand "$exec_flag" "$ON_ERR_CONT" "echo \"$pkg\" >> \"$pName/requirements.txt\""
        done
    else
        log_warn "No packages specified with the -p flag."
        runCommand "$exec_flag" "$ON_ERR_EXIT" "echo '# No packages specified' > \"$pName/requirements.txt\""
    fi
}


# ==============================================================================
# Main Orchestration Function
# ==============================================================================
main() {
    # 1. Handle all script initialization with one call.
    if ! lib_initializeScript "$@"; then
        return 1
    fi

    # The rest of the arguments are now clean for the script's own use if needed.
    shift "$g_consumed_args"

    # 2. Orchestrate the core logic, using the globally-set $g_execution_flag.
    log_instr "Project Name: $projectName"
    handle_directory "$projectName" "$g_execution_flag"
    handle_git "$projectName" "$gitRepoUrl" "$g_execution_flag"
    handle_dependencies "$projectName" "$skipDeps" "$g_execution_flag" "${packages[@]}"

    log_instr "✅ Script finished."
}

# ==============================================================================
# Main Execution Guard
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
