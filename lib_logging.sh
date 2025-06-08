#!/usr/local/bin/bash
# set -x

# ###########################
# Template variables # {{{
args=("$@")

filename="$(basename "${BASH_SOURCE[0]}")"
isSourcedName="sourced_${filename/./_}"
if declare -p "$isSourcedName" > /dev/null 2>&1; then 
        echo 1; 
        return 1; 
else 
        declare "$isSourcedName=$filename" 
fi

declare -r -l lib_fcn_name="logging"

# Log levels (lower number = more detailed)
declare -g -r -A LOG_LEVELS=( [trace]=1 [debug]=2 [info]=3 [warn]=4 [error]=5 [instr]=99)
#
# Default log level
# -g global, -l lowercase
declare -g -l current_logging_level="warn"
# declare -g -l include_time_stamp=0
# }}}
# ###########################

# ***********************************
source_dependencies() { # {{{
    local pathname_to_source=""

    # Source file to get the thisFile fcn
    if [ -f "$(dirname "$0")/lib_thisFile.sh" ]; then
        pathname_to_source="$(dirname "$0")/lib_thisFile.sh"
        source "$pathname_to_source"
    fi

    # Source color library if it exists 
    if [ -f "$(dirname "$0")/lib_colors.sh" ]; then
        pathname_to_source="$(dirname "$0")/lib_colors.sh"
        source "$pathname_to_source"

        if [ 1 -eq 0 ]; then
            echo "Logging will use colors:" >&2
            echo "   $Color_Instr Instr$Color_Instr $Color_Reset"   >&2
            echo "   $Color_Error Error$Color_Error $Color_Reset"   >&2
            echo "   $Color_Warn Warn$Color_Warn $Color_Reset"      >&2
            echo "   $Color_Info Info$Color_Info $Color_Reset"      >&2
            echo "   $Color_Debug Debug$Color_Debug $Color_Reset"   >&2
            echo "   $Color_Trace Trace$Color_Trace $Color_Reset"   >&2
            echo "   $Color_Reset Reset${Color_Reset} $Color_Reset" >&2
        fi
    else
        echo "[warn] lib_colors.sh not found. Custom output colors not available." >&2
        Color_Error=""  # Instructions
        Color_Error=""
        Color_Warn=""
        Color_Info=""
        Color_Debug=""
        Color_Trace=""
        Color_Reset=""
    fi
} 
# }}}
# ***********************************

# ***********************************
# parseArgs() {{{
# Parses command-line arguments passed to the script.
parseArgs() {
    # echo "$(thisFile): Current log level: $current_logging_level"
    while (( "$#" )); do
        log_debug "$(thisFile): Processing argument: $1"
        case "$1" in
            --set-log-level)
                shift
                log_level=$1
                set_log_level $log_level
                shift
                ;;
            --test)
                shift
                local test_target=$1
                libTests_addTest "$test_target"
                shift
                ;;
            -help)
                shift
                local helpFcnToRun=$1
                libHelp_addHelp "$helpFcnToRun"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
} #}}}
# ***********************************

# ***********************************
# set_log_level {{{
# Set log level function
set_log_level() {
    local level=$1
    echo "HELLO! Setting log level to: $level from: $(thisCaller)"
    log_debug "$(thisFile): set_log_level $current_logging_level -> $level"
    current_logging_level=$level
}
# }}}
# ***********************************

# ***********************************
# print_log_level  {{{
print_log_level() {
    local theKey=""
    local logLevel=""
    if [[ -z "$1" ]]; then
        if [[ ${#LOG_LEVELS[@]} -eq 0 ]]; then
            echo "ERROR:$(thisFile):$LINENO: LOG_LEVELS not defined..."
        else
            echo "---- Start Print All Log Levels $(thisFile):$LINENO -----" 
            for key in "${!LOG_LEVELS[@]}"; do
                local color_var="Color_${key^}"
                local color=${!color_var}

                echo "${color}Key: $key, value: ${LOG_LEVELS[$key]}${Color_Reset}"
            done
            echo "---- End Print All Log Levels $(thisFile):$LINENO -----"
        fi
    else
        # echo "Parameter: $1" >&2
        echo "LOG_LEVELS[$1]=$LOG_LEVELS[$1]"
    fi
}
# }}}
# ***********************************

# ***********************************
# log_message {{{
#   log_message level caller [lineno] msg
#   
log_message() {
    # echo "log_message: $@"
    local level="$1" ; shift
    local caller=""
    local line_number=""
    local message=""
    local msg_log_level="$level" # should be text
    local msg_log_value="${LOG_LEVELS[$level]}" # should be numeric
    local current_logging_level="$current_logging_level}"
    local current_logging_value="${LOG_LEVELS[$current_logging_level]}"
    local color_var=""
    local color=""

    log_debug "log_message-$(thisFile): level=$level, line_no=$line_number, msg_log_level=$msg_log_level, msg_log_value=$msg_log_value, current_logging_level=$current_logging_level, current_logging_value=$current_logging_value, caller=$caller, message='$@'" >&2

    if [[ $msg_log_level -eq ${LOG_LEVELS["instr"]} ]]; then
        # instr logging level OR logging levels not set" 
        # If it's an Instruction, then add nothing else to the line
        message="$@"
    else
        caller="$1"; shift
        line_number="$1"
        
        # Check if the first argument is a number (line number)
        if [[ $line_number =~ ^[0-9]+$ ]]; then
            shift # Remove the line number from the arguments
            message="[$level] [$caller:$line_number] $@" 
        else
            line_number=""
            message="[$level] [$caller] $@"
        fi
        
        color_var="Color_${level^}"
        color=${!color_var}
    fi

    if [[ $msg_log_level -le $current_logging_value ]]; then
        echo "${color}$message${Color_Reset}" >&2
    fi
}
# }}}
# ***********************************

# ***********************************
# log_* functions {{{
# Specific log functions
# These treat the msg ($@) as just a msg
log_trace() { log_message "trace" "$(thisCaller)" "$@"; }
log_debug() { log_message "debug" "$(thisCaller)" "$@"; }
log_info()  { log_message "info"  "$(thisCaller)" "$@";  }
log_warn()  { log_message "warn"  "$(thisCaller)" "$@";  }
log_error() { log_message "error" "$(thisCaller)" "$@"; }
log_instr() { log_message "instr" "$@";                 } # Instruction

# These print the line and then execute the line
# as if $@ was a cmd
cmd_trace() { log_trace "$@"; eval "$@"; }
cmd_debug() { log_debug "$@"; eval "$@"; }
cmd_info()  { log_info  "$@"; eval "$@"; }
cmd_warn()  { log_warn  "$@"; eval "$@"; }
cmd_error() { log_error "$@"; eval "$@"; }
cmd_instr() { log_instr "$@"; eval "$@"; }
# }}}
# ***********************************

# ***********************************
# {{{ trace_fcn
# Function for automatic entry and exit logs
trace_fcn() {
    # echo "trace_fcn $@"
    local func_name=$1
    shift
    local line_number=$1

    # Check if the first argument is a number (line number)
    if [[ $line_number =~ ^[0-9]+$ ]]; then
        shift # Remove the line number from the arguments
    else 
        line_number=""
    fi
    log_message "trace" "$line_number" "Enter: $func_name $@"
    "$func_name" "$@"
    log_message "trace" "$line_number" "Exit: $func_name"
}
# }}}
# ***********************************

# *********************************** 
# Test logging fcns {{{
test_logging() { 
    local save_logging_level=print_log_level
    set_log_level "trace"

    echo "************************************" >&2
    echo "***** $(thisFile):$LINENO *****" >&2
    echo "***** BEGIN TESTING LOG LEVELS *****" >&2
    echo "" >&2

    echo "---- Start Print All Log Levels -----" >&2
    echo "$(print_log_level)" >&2
    echo "---- End Print All Log Levels -----" >&2

    echo "$(test_logging_fcn 'trace')" >&2
    echo "$(test_logging_fcn 'debug')" >&2
    echo "$(test_logging_fcn 'info')" >&2
    echo "$(test_logging_fcn 'warn')" >&2
    echo "$(test_logging_fcn 'error')" >&2
    echo "$(test_logging_fcn 'instr')" >&2

    set_log_level "$save_logging_level"
    echo "" >&2
    echo "***** END TESTING LOG LEVELS *****" >&2
    echo "************************************" >&2
}
test_logging_fcn() { 
    local levelName=$1
    local logFcnName="log_${levelName}"
    local cmdFcnName="cmd_${levelName}"

    echo "# =====================================================" >&2
    echo "# Test $levelName with function $logFcnName and $cmdFcnName." >&2
    echo "# -----------------------------------------" >&2
    echo "A $levelName message without a lineno" >&2
    eval "$logFcnName 'A $levelName message without a lineno' - HOME: $(basename $HOME)" >&2
    echo "A $levelName message with a lineno" >&2
    eval "$logFcnName $LINENO 'A $levelName message with a lineno' - HOME: $(basename $HOME)" >&2
    echo "" >&2
    echo "A cmd $levelName message to log and execute" >&2
    echo "$cmdFcnName echo -n '$LINENO*$LINENO = '; echo '$LINENO*$LINENO' | bc" >&2
    eval "$cmdFcnName echo -n '$LINENO*$LINENO = '; echo '$LINENO*$LINENO' | bc" >&2
    echo "=======================================================" >&2
}
# }}}
# ***********************************

# Example usage of logging
# Define a regular function
# my_function() {
#     # Function body
# }
# Call it using auto_log for automatic logging
# trace_fcn my_function arg1 arg2

source_dependencies

# Conditionals to optionally include elsewhere {{{
# Replacement log_* statements that could be used to ensure robustness
if ! declare -f log_debug > /dev/null 2>&1; then 
    log_debug() { 
        echo "$@" 
    } fi
if ! declare -f log_info  > /dev/null 2>&1; then 
    log_info()  { 
        echo "$@" 
    } 
fi
if ! declare -f log_warn  > /dev/null 2>&1; then 
    log_warn()  { 
        echo "$@" 
    } 
fi
if ! declare -f log_error > /dev/null 2>&1; then 
    log_error() { 
        echo "$@" 
    } 
fi
if ! declare -f log_instr > /dev/null 2>&1; then 
    log_instr() { 
        echo "$@" 
    } 
fi
# }}}

# ***********************************
# This should move to a help-usage library # {{{
# help-usage
# ***********************************
#
if [[ -z lib_helps_helpFcnsToRun ]]; then
    declare -a -g -l lib_helps_helpFcnsToRun
fi

if [[ -z lib_help_runHelp ]]; then
    declare -g -l lib_help_runHelp
fi
if [[ ! -z lib_help_runHelp  && $lib_help_runHelp ]]; then
    libFcn_help_run
fi

# Add a help fcn to call
libFcn_addHelp() { lib_helpFcnsToRun+=("$1"); }

# Loop through the helps listed on the command line 
libFcn_helpRun() {
    # Loop through the tests array and call corresponding functions
    for fcn in "${lib_helpFcnsToRun[@]}"; do
        help_function="help_$fcn"
        if declare -f "$help_function" > /dev/null; then
            "$help_function"
        else
            echo "Help function $help_function not found."
        fi
    done
}

# help_logging
help_logging() {
   
    log_info "Usage: lib_logging.sh is a ilbrary that is not intended to run directly as a script, but included as a library."
    log_info "Options:"
    log_info "  --help $lib_fcn_name, --usage $lib_fcn_name: Display help or usage for library or fcn: $lib_fcn_name"
    log_info "  --set-log-level \"log_level_name\": sets the current log level to one of:  {\"error\", \"ward\", \"info\", \"debug\", \"trace\", \"instr\" } "
    log_info "  --test $lib_fcn_name: Execute the test(s) for the $lib_fcn_name library"
    log_info "Description:"
    log_info "  <something useful and instructional about logging> "
    log_info "  "
}
usage_logging() {
    help_logging
}
# }}}
# ***********************************

# ***********************************
# This should move to a testing library # {{{
if [[ -z test_fcns_to_run ]]; then
    declare -a -g -l test_fcns_to_run
fi

libTests_addTest() { test_fcns_to_run+=("$1"); }
runTests() {
    # Loop through the tests array and call corresponding functions
    for test in "${test_fcns_to_run[@]}"; do
        test_function="test_$test"
        if declare -f "$test_function" > /dev/null; then
            "$test_function"
        else
            echo "Test function $test_function not found."
        fi
    done
}
# }}}
# ***********************************

parseArgs "${args[@]}"
# runTests

