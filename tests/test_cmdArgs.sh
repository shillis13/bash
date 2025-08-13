#!/usr/bin/env bash
#
# ==============================================================================
# TEST SUITE: lib_cmdArgs
# ==============================================================================

run_suite() {
    local overall_status=0
    log_banner "--- BEGIN Test lib_cmdArgs.sh ---"

    # Define a local function for this test scope
    define_test_args() {
        libCmd_add -t value  --long input-file -f i -v "inputFile" -r y -u "Input file"
        libCmd_add -t switch --long verbose    -f v -v "verboseMode" -d "$FALSE" -u "Enable verbose mode"
        libCmd_add -t value  --long packages   -f p -v "pkg_list" -m multi -u "Packages to install"
    }

    # Unset variables to ensure a clean test
    unset inputFile verboseMode pkg_list

    define_test_args
    libCmd_parse --input-file "my.txt" -v --packages "vim" -p "git"

    local test_failed=$FALSE
    if [[ "$inputFile" != "my.txt" ]]; then
        log --error "FAIL: inputFile was not set correctly. Expected 'my.txt', got '$inputFile'."
        test_failed=$TRUE
    fi
    if (( ! verboseMode )); then
        log --error "FAIL: verboseMode switch was not set correctly."
        test_failed=$TRUE
    fi
    if [[ "${#pkg_list[@]}" -ne 2 ]] || [[ "${pkg_list[0]}" != "vim" ]] || [[ "${pkg_list[1]}" != "git" ]]; then
        log --error "FAIL: pkg_list multi-argument was not set correctly."
        test_failed=$TRUE
    fi

    if (( ! test_failed )); then
        log --test "PASS: libCmd_parse correctly set all variable types."
    else
        overall_status=1
    fi

    log_banner "--- END Test lib_cmdArgs.sh ---"
    return $overall_status
}


