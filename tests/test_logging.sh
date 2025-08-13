#!/usr/bin/env bash

# ==============================================================================
# TEST SUITE: lib_logging
# ==============================================================================

run_suite() {
    local overall_status=0
    local original_level="$current_logging_level"
    local test_log_file="temp_test_log.txt"

    set_log_file "$test_log_file"
    trap 'rm -f "$test_log_file"' EXIT

    log_banner "BEGIN COMPREHENSIVE LOGGING TEST"

    local levels_to_test=("error" "warn" "info" "debug" "entryexit" "none")

    for level_to_set in "${levels_to_test[@]}"; do
        log_banner "--- Testing Log Level: '$level_to_set' ---"
        set_log_level "$level_to_set" # Correctly call with a parameter
        >"$test_log_file"

        # Generate all message types using the corrected 'log' function
        log --entryexit "Entry/Exit Message"
        log --debug "Debug Message"
        log --info "Info Message"
        log --warn "Warn Message"
        log --error "Error Message"

        local test_failed_for_this_level=$FALSE
        # Verification logic remains the same...
        for level_to_verify in "${!LOG_LEVELS[@]}"; do
            if [[ "$level_to_verify" == "none" ]]; then continue; fi
            local -i should_be_present=0
            if (( ${LOG_LEVELS[$level_to_verify]} >= ${LOG_LEVELS[$level_to_set]} )); then
                should_be_present=1
            fi

            local was_seen=$FALSE
            if grep -q "\[${level_to_verify^^}\]" "$test_log_file"; then
                was_seen=$TRUE
            fi

            if (( should_be_present == 1 )) && (( ! was_seen )); then
                log --error "FAIL: Expected to find '[${level_to_verify^^}]' in log, but it was absent."
                test_failed_for_this_level=$TRUE
            elif (( should_be_present == 0 )) && (( was_seen )); then
                log --error "FAIL: Did NOT expect to find '[${level_to_verify^^}]' in log, but it was present."
                test_failed_for_this_level=$TRUE
            fi
        done

        if (( ! test_failed_for_this_level )); then
            log_always "PASS: Log level '$level_to_set' filtered messages correctly."
        else
            overall_status=1
        fi
    done

    set_log_level "$original_level"
    set_log_file "" # Unset the log file
    log_banner "COMPREHENSIVE LOGGING TEST END"

    return $overall_status
}

