#!/usr/bin/env bash
#
# ==============================================================================
# LIBRARY: lib_sysInfoUtils.sh
#
# DESCRIPTION: A library for retrieving system and environment information.
# ==============================================================================

# --- Guard ---
[[ -z "$LIB_SYS_INFO_UTILS_LOADED" ]] && readonly LIB_SYS_INFO_UTILS_LOADED=1 || return 0

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# ------------------------------------------------------------------------------
# SECTION: File System Type Checks
# ------------------------------------------------------------------------------

is_file() { [[ -f "$1" ]]; }
is_dir() { [[ -d "$1" ]]; }
is_link() { [[ -L "$1" ]]; }
is_exe() { [[ -x "$1" ]]; }
is_readable() { [[ -r "$1" ]]; }
is_writable() { [[ -w "$1" ]]; }
is_writable_dir() { is_dir "$1" && is_writable "$1" ; }

# ------------------------------------------------------------------------------
# SECTION: Get System Info
# ------------------------------------------------------------------------------
get_os() { uname -s; }

get_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "$NAME"
    else
        uname -s
    fi
}

get_ip() { hostname -I | awk '{print $1}'; }

get_public_ip() {
    dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || curl -s ifconfig.me
}

get_user() { whoami; }

get_host() { hostname; }

# ------------------------------------------------------------------------------
# SECTION: Get Performance Metrics
# ------------------------------------------------------------------------------
get_cpu_usage() {
    # This is a simplified version; more accurate methods are complex.
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage "%"}';
}

get_mem_usage() { free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }'; }

get_disk_usage() { df -h / | awk 'NR==2{print $5}'; }

get_load_avg() { uptime | awk -F'load average: ' '{print $2}'; }

get_uptime() { uptime -p; }



