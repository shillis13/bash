#!/usr/bin/env bash

# ==============================================================================
# SCRIPT: host_info
#
# DESCRIPTION: Gathers and displays a wide range of system statistics with
#              color-coded performance indicators and readable units.
# ==============================================================================

# ==============================================================================
# TODOs for Future Enhancements
# ==============================================================================
#
# TODO: Full Performance Analysis - Expand on the color-coding to provide more
#       qualitative assessments (good/bad/ok) for metrics like memory
#       pressure, I/O wait, and other complex stats.
#
# TODO: Interactive Mode - Create a 'top'-like mode that clears the screen
#       and refreshes the statistics every few seconds.
#
# TODO: Historical Logging - Add a feature to append key metrics (CPU, load,
#       memory) to a structured log file (e.g., /var/log/host_stats.csv)
#       for tracking performance over time.
#
# TODO: Graphical Output - Add a feature to generate simple text-based
#       bar charts for key metrics like CPU and Memory usage.
#
# TODO: Explanatory Output Mode - Add a flag (e.g., --explain) that
#       interleaves the detailed help text (currently in log_debug)
#       directly with the metrics in the main output.
#
# ==============================================================================

# --- Sourcing the Library ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR/libs/lib_main.sh"
lib_require "lib_format.sh"

# --- Script-Specific Functions ---
define_arguments() {
    lib_logging_initialize
    libCmd_add -t switch -f h --long help -v "showHelp" -d "false" -m once -u "Display this help message."
}

# --- Data Gathering Functions ---
get_os_info() {
    log_instr "--- System Information ---"
    if [[ "$(uname)" == "Linux" ]]; then
        log_instr "OS Info:"
        log_instr "$(lsb_release -a 2>/dev/null || cat /etc/os-release)"
    else # macOS
        log_instr "OS Info:"
        log_instr "$(sw_vers)"
    fi
    log_instr "Uptime: $(uptime)"
}

get_cpu_info() {
    log_instr "" # Add spacing
    log_instr "--- CPU Information ---"
    if [[ "$(uname)" == "Linux" ]]; then
        local num_cores; num_cores=$(nproc)
        local load; load=$(cut -d' ' -f1 < /proc/loadavg)
        local load_color; load_color=$(format_color_by_threshold "$load" "$num_cores" "$((num_cores * 2))")
        log_instr "Load Average (1m): ${load_color}${load}${Color_Reset} / ${num_cores}.0 cores"
        log_debug "  (Load per core. Green < 1.0, Yellow >= 1.0, Red >= 2.0)"

        local cpu_usage; cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
        local usage_color; usage_color=$(format_color_by_threshold "$cpu_usage" 75 90)
        log_instr "CPU Usage:         ${usage_color}${cpu_usage}%${Color_Reset}"
        log_debug "  (Total CPU utilization across all cores)"

    else # macOS
        local num_cores; num_cores=$(sysctl -n hw.ncpu)
        local load; load=$(sysctl -n vm.loadavg | awk '{print $2}')
        local load_color; load_color=$(format_color_by_threshold "$load" "$num_cores" "$((num_cores * 2))")
        log_instr "Load Average (1m): ${load_color}${load}${Color_Reset} / ${num_cores}.0 cores"
        log_debug "  (Load per core. Green < 1.0, Yellow >= 1.0, Red >= 2.0)"

        local idle; idle=$(top -l 1 | grep 'CPU usage' | awk '{print $7}' | cut -d'%' -f1)
        local usage; usage=$(echo "100 - $idle" | bc)
        local usage_color; usage_color=$(format_color_by_threshold "$usage" 75 90)
        log_instr "CPU Usage:         ${usage_color}${usage}%${Color_Reset}"
        log_debug "  (Total CPU utilization across all cores)"
    fi
}

get_mem_info() {
    log_instr "" # Add spacing
    log_instr "--- Memory Information ---"
    if [[ "$(uname)" == "Linux" ]]; then
        log_instr "Memory Usage:"
        log_instr "$(free -h)"
    else # macOS
        local page_size; page_size=$(sysctl -n hw.pagesize)
        local total_mem_gb; total_mem_gb=$(sysctl -n hw.memsize | awk '{print $1/1024/1024/1024" GB"}')
        log_instr "Total Physical Memory: $total_mem_gb"
        log_instr ""
        log_instr "macOS Memory Breakdown (page size: $(printf "%'d" "$page_size") bytes):"
        log_debug "  (macOS actively uses 'inactive' memory as cache; low 'free' pages is normal)"

        # --- Two-Pass Approach for Perfect Alignment ---
        local -a vm_stat_lines
        local max_gb_width=0

        # Pass 1: Read data and calculate the maximum width for the formatted GB value
        mapfile -t vm_stat_lines < <(vm_stat)
        for line in "${vm_stat_lines[@]}"; do
            local value; value=$(echo "$line" | cut -d: -f2)
            local num_pages; num_pages=$(echo "$value" | tr -d '[:space:].')
            if [[ "$num_pages" =~ ^[0-9]+$ ]]; then
                local gb_num; gb_num=$(format_pages_to_gb "$num_pages" "$page_size")
                local formatted_gb_num; formatted_gb_num=$(printf "%'.2f" "$gb_num")
                local current_width=${#formatted_gb_num}
                if (( current_width > max_gb_width )); then
                    max_gb_width=$current_width
                fi
            fi
        done

        # Pass 2: Print the formatted output using the calculated max_gb_width
        for line in "${vm_stat_lines[@]}"; do
            local key; key=$(echo "$line" | cut -d: -f1)
            local value; value=$(echo "$line" | cut -d: -f2)
            local num_pages; num_pages=$(echo "$value" | tr -d '[:space:].')

            case "$key" in
                '"Translation faults"'|'File-backed pages'|'Pageins')
                    printf "\n"
                    ;;
            esac

            if [[ "$num_pages" =~ ^[0-9]+$ ]]; then
                local formatted_pages; formatted_pages=$(printf "%'14d" "$num_pages")
                local gb_num; gb_num=$(format_pages_to_gb "$num_pages" "$page_size")
                # Use the calculated max_gb_width with '*' in the format string for dynamic padding
                printf "  %-30s : %s ( %'*s GB )\n" "$key" "$formatted_pages" "$max_gb_width" "$(printf "%'.2f" "$gb_num")"
            fi
        done
    fi
}

# --- Main Orchestration Function ---
main() {
    if ! lib_initializeScript "$@"; then
        return 1
    fi
    set_log_level # Apply --log-level from arguments

    log_info "Gathering host information at $(date)..."
    get_os_info
    get_cpu_info
    get_mem_info
    log_instr ""
    log_instr "✅ Host info gathering complete."
}

# --- Main Execution Guard ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi

