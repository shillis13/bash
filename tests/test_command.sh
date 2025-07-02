#!/usr/bin/env bash
#
# ==============================================================================
# TEST SUITE: lib_command
# ==============================================================================

run_suite() {
    local overall_status=0

    log_banner "--- BEGIN Test lib_command.sh ---"

    # --- Test 1: Dry Run Mode (Default) ---
    local output
    output=$(runCommand "echo 'hello'" 2>&1)
    if [[ "$output" == *"Dry Run: echo 'hello'"* ]]; then
        log --test "PASS: runCommand correctly performs a dry run by default."
    else
        log --error "FAIL: runCommand did not perform a dry run."
        overall_status=1
    fi

    # --- Test 2: Execution Mode ---
    output=$(runCommand --exec "echo 'hello'")
    if [[ "$output" == "hello" ]]; then
        log --ttest "PASS: runCommand correctly executes a command with --exec."
    else
        log --error "FAIL: runCommand did not execute the command."
        overall_status=1
    fi

    # --- Test 3: ON_ERR_EXIT (Default) ---
    # We run this in a subshell to catch the exit
    ( runCommand --exec "false" )
    if [[ $? -ne 0 ]]; then
        log --ttest "PASS: runCommand with ON_ERR_EXIT correctly exits on failure."
    else
        log --error "FAIL: runCommand with ON_ERR_EXIT did not exit on failure."
        overall_status=1
    fi

    # --- Test 4: ON_ERR_CONT ---
    runCommand --exec "$ON_ERR_CONT" "false"
    if [[ $? -ne 0 ]]; then
        log --ttest "PASS: runCommand with ON_ERR_CONT correctly continues on failure."
    else
        log --error "FAIL: runCommand with ON_ERR_CONT exited on failure."
        overall_status=1
    fi

    log_banner "--- END Test lib_command.sh ---"
    return $overall_status
}


