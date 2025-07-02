#!/usr/bin/env bash

# ==============================================================================
# TEST SUITE: lib_fs
# ==============================================================================

run_suite() {
    lib_require "lib_fs.sh"
    local overall_status=0

    log_banner "--- BEGIN Test lib_fs.sh ---"

    # --- Setup ---
    local temp_dir
    temp_dir=$(mktemp -d)
    local temp_file="${temp_dir}/my_file.txt"
    touch "$temp_file"
    trap 'rm -rf "$temp_dir"' EXIT

    # --- Test 1: file_exists ---
    if file_exists "$temp_file"; then
        log --test "PASS: file_exists correctly found an existing file."
    else
        log --error "FAIL: file_exists did not find an existing file."
        overall_status=1
    fi
    if ! file_exists "$temp_file-does-not-exist"; then
        log --test "PASS: file_exists correctly reported a non-existent file."
    else
        log --error "FAIL: file_exists reported a non-existent file as existing."
        overall_status=1
    fi

    # --- Test 2: dir_exists_and_writable ---
    if dir_exists_and_writable "$temp_dir"; then
        log --test "PASS: dir_exists_and_writable correctly found a valid directory."
    else
        log --error "FAIL: dir_exists_and_writable did not find a valid directory."
        overall_status=1
    fi
    if ! dir_exists_and_writable "/non_existent_dir_12345"; then
        log --test "PASS: dir_exists_and_writable correctly reported a non-existent directory."
    else
        log --error "FAIL: dir_exists_and_writable reported a non-existent directory as existing."
        overall_status=1
    fi

    log_banner "--- END Test lib_fs.sh ---"
    return $overall_status
}


