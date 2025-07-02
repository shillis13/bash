#!/usr/bin/env bash
#
# ==============================================================================
# TEST SUITE: lib_grep
# This is a passive file containing test functions for the runner to execute.
# ==============================================================================

run_suite() {
    # This suite needs the lib_grep functions to be loaded.
    lib_require "lib_grep.sh"

    local test_file="temp_grep_test_data.log"
    local tests_failed=0

    # Create a temporary file with known data to test against
    cat > "$test_file" << EOF
2025-07-01 10:20:30 INFO: Service started.
[01/Jul/2025:10:20:31 -0400] "GET /health" 200
ERROR: Connection from 192.168.1.101 failed.
WARN: Login attempt for user 'admin' from 10.0.0.5 succeeded.
EOF
    trap 'rm -f "$test_file"' EXIT

    # --- Test 1: grepIpv4Addresses function ---
    local output
    output=$(grepIpv4Addresses "$test_file")
    if [[ "$output" == *"192.168.1.101"* ]] && [[ "$output" == *"10.0.0.5"* ]]; then
        log -Test "PASS: grepIpv4Addresses() found both expected IP addresses."
    else
        log -Error "FAIL: grepIpv4Addresses() did not find expected IPs."
        tests_failed=$((tests_failed + 1))
    fi

    # --- Test 2: grepDates function ---
    output=$(grepDates "$test_file")
    if [[ "$output" == *"2025-07-01"* ]] && [[ "$output" == *"01/Jul/2025"* ]]; then
        log -Test "PASS: grepDates() found both expected date formats."
    else
        log -Error "FAIL: grepDates() did not find both date formats."
        tests_failed=$((tests_failed + 1))
    fi

    return $tests_failed
}

