#!/usr/bin/env bash
# ==============================================================================
# SCRIPT: file_io_stress_test
#
# DESCRIPTION: A tool to test file I/O performance under stress.
# ==============================================================================

# --- Sourcing the Library ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR/libs/lib_main.sh"
source "$SCRIPT_DIR/libs/lib_utils.sh"

# --- Defaults ---
DEFAULT_MAX_SIZE_MB=100
DEFAULT_MAX_ITERATIONS=10000
DEFAULT_IOSTAT_LOG="iostat.log"
DEFAULT_IOSTAT_INTERVAL=5
DEFAULT_FILE_PREFIX="file_io_stress"

# --- Runtime Globals (used by cleanup trap) ---
g_file1=""
g_file2=""
g_iostat_pid=""
g_keep_files=0

# --- Script-Specific Functions ---
define_arguments() {
    libCmd_add -t switch -f h --long help -v "showHelp" -d "false" -m once -u "Display this help message."
    libCmd_add -t value -f m --long max-size -v "max_size" -d "$DEFAULT_MAX_SIZE_MB" -m once -u "Max file size in MB (integer)."
    libCmd_add -t value -f i --long iterations -v "max_iterations" -d "$DEFAULT_MAX_ITERATIONS" -m once -u "Max number of loop iterations."
    libCmd_add -t value -f l --long log-file -v "iostat_log" -d "$DEFAULT_IOSTAT_LOG" -m once -u "Log file for iostat (relative to work dir unless absolute)."
    libCmd_add -t value -f w --long work-dir -v "work_dir" -d "." -m once -u "Directory to create test files (default: current directory)."
    libCmd_add -t value -f p --long prefix -v "file_prefix" -d "$DEFAULT_FILE_PREFIX" -m once -u "Prefix for generated test files."
    libCmd_add -t value      --long iostat-interval -v "iostat_interval" -d "$DEFAULT_IOSTAT_INTERVAL" -m once -u "Seconds between iostat samples."
    libCmd_add -t switch     --long no-iostat -v "no_iostat" -d "$FALSE" -m once -u "Disable iostat logging."
    libCmd_add -t switch     --long keep-files -v "keep_files" -d "$FALSE" -m once -u "Keep generated files after the run."
}

print_help() {
    cat <<EOF
file_io_stress_test.sh - Stress-test file I/O by repeatedly appending files.

Usage:
  file_io_stress_test.sh [options]

Options:
  -h, --help                 Show this help message (also -?)
  -m, --max-size MB          Stop when either file reaches MB size (default: ${DEFAULT_MAX_SIZE_MB})
  -i, --iterations N         Max loop iterations (default: ${DEFAULT_MAX_ITERATIONS})
  -l, --log-file PATH        iostat output path (default: ${DEFAULT_IOSTAT_LOG})
  -w, --work-dir DIR         Directory to create test files (default: current directory)
  -p, --prefix STR           Prefix for generated files (default: ${DEFAULT_FILE_PREFIX})
      --iostat-interval SEC  Seconds between iostat samples (default: ${DEFAULT_IOSTAT_INTERVAL})
      --no-iostat            Disable iostat logging
      --keep-files           Keep generated files after the run

Notes:
  - Test files grow exponentially; use small limits for quick runs.
  - If iostat is unavailable, logging is skipped with a warning.
  - Relative --log-file paths are resolved against --work-dir.

Examples:
  file_io_stress_test.sh --max-size 10 --iterations 50
  file_io_stress_test.sh -w /tmp -p io_test --max-size 5 --iterations 20
  file_io_stress_test.sh --no-iostat --keep-files
EOF
}

cleanup() {
    local exit_code=$?
    if [[ -n "$g_iostat_pid" ]]; then
        kill "$g_iostat_pid" 2>/dev/null || true
    fi
    if (( ! g_keep_files )); then
        [[ -n "$g_file1" ]] && rm -f "$g_file1"
        [[ -n "$g_file2" ]] && rm -f "$g_file2"
    fi
    return "$exit_code"
}

# --- Main Orchestration Function ---
main() {
    local pre_show_help=0
    local filtered_args=()
    for arg in "$@"; do
        if [[ "$arg" == "-?" ]]; then
            pre_show_help=1
        else
            filtered_args+=("$arg")
        fi
    done

    if ! initializeScript "${filtered_args[@]}"; then return 1; fi

    if (( pre_show_help )); then
        showHelp=1
    fi
    if (( showHelp )) || (( ShowHelp )); then
        print_help
        return 0
    fi

    local statCmd dateCmd
    local osType; osType=$(uname)

    # Cross-platform setup for stat and date commands
    if [[ "$osType" == "Darwin" ]]; then
        statCmd="stat -f %z"
        dateCmd="date +%s" # Simplified for cross-platform math
    elif [[ "$osType" == "Linux" ]]; then
        statCmd="stat -c %s"
        dateCmd="date +%s%N"
    else
        log --Warn "Unrecognized OS type '$osType', defaulting to Linux commands."
        statCmd="stat -c %s"
        dateCmd="date +%s%N"
    fi

    if ! [[ "$max_size" =~ ^[0-9]+$ ]] || (( max_size <= 0 )); then
        log --Error "--max-size must be a positive integer MB value."
        return 1
    fi
    if ! [[ "$max_iterations" =~ ^[0-9]+$ ]] || (( max_iterations < 0 )); then
        log --Error "--iterations must be a non-negative integer."
        return 1
    fi
    if ! [[ "$iostat_interval" =~ ^[0-9]+$ ]] || (( iostat_interval <= 0 )); then
        log --Error "--iostat-interval must be a positive integer."
        return 1
    fi

    if [[ -z "$work_dir" ]]; then
        work_dir="."
    fi
    if [[ ! -d "$work_dir" ]]; then
        log --Error "Work dir does not exist: $work_dir"
        return 1
    fi
    work_dir=$(cd "$work_dir" && pwd -P)

    if [[ "$iostat_log" != /* ]]; then
        iostat_log="$work_dir/$iostat_log"
    fi

    g_keep_files=$keep_files
    trap cleanup EXIT

    local max_bytes=$((max_size * 1024 * 1024))

    log --Info "Starting File I/O Stress Test..."
    log --Info "Max size: ${max_size}MB, Max iterations: ${max_iterations}"
    log --Info "Work dir: ${work_dir}" 
    log --Info "iostat log: ${iostat_log}"

    # Create test files
    g_file1=$(mktemp "${work_dir%/}/${file_prefix}_1_XXXXXX")
    g_file2=$(mktemp "${work_dir%/}/${file_prefix}_2_XXXXXX")
    runCommand --exec "printf '%s\n' 'Test file 1' > \"$g_file1\""
    runCommand --exec "printf '%s\n' 'Test file 2' > \"$g_file2\""

    # Start iostat in the background
    if (( no_iostat )); then
        log --Warn "iostat disabled by --no-iostat."
    elif command -v iostat >/dev/null 2>&1; then
        log --Info "Starting iostat in the background..."
        if [[ "$osType" == "Darwin" ]]; then
            iostat -w "$iostat_interval" >> "$iostat_log" &
        else
            iostat -c "$iostat_interval" >> "$iostat_log" &
        fi
        g_iostat_pid=$!
    else
        log --Warn "iostat not found; skipping iostat logging."
    fi

    local reads=0 writes=0 iterations=0
    local size1=0 size2=0
    local start_time; start_time=$($dateCmd)

    while (( iterations < max_iterations )); do
        runCommand --exec "cat \"$g_file1\" >> \"$g_file2\""
        runCommand --exec "cat \"$g_file2\" >> \"$g_file1\""
        
        # Increment counters
        writes=$((writes + 2))
        reads=$((reads + 2))
        iterations=$((iterations + 1))

        size1=$($statCmd "$g_file1")
        size2=$($statCmd "$g_file2")
        if (( size1 >= max_bytes || size2 >= max_bytes )); then
            break
        fi
    done

    local end_time; end_time=$($dateCmd)

    local elapsed_sec
    if [[ "$osType" == "Darwin" ]]; then
        elapsed_sec=$((end_time - start_time))
    else
        local elapsed_ns=$((end_time - start_time))
        elapsed_sec=$((elapsed_ns / 1000000000))
    fi

    log --Instr "✅ Stress test complete."
    log --Instr "Iterations: $iterations"
    log --Instr "Final sizes (bytes): file1=$size1, file2=$size2"
    log --Instr "Elapsed: ${elapsed_sec}s"
}

# --- Main Execution Guard ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
