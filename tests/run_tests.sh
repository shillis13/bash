#!/usr/bin/env bash
#
# ==============================================================================
# SCRIPT: run_tests.sh
# ==============================================================================

# --- Sourcing the Library ---
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
source "$SCRIPT_DIR/../libs/lib_main.sh"

# ==============================================================================
# Script Setup and Main Logic
# ==============================================================================

define_arguments() {
    libCmd_add -t switch -f h --long help -v "showHelp" -d "false" -m once -u "Display this help message."
    libCmd_add -t value  -f t --long test -v "tests_to_run" -m multi -u "Optional: Specify a test to run. Defaults to all."
}

main() {
    if ! initializeScript "$@"; then
        return 1
    fi

    local test_dir="${SCRIPT_DIR}"
    if [[ ! -d "$test_dir" ]]; then
        log -e "Tests directory not found at: $test_dir"
        exit 1
    fi

    local -a available_tests
    mapfile -t available_tests < <(find "$test_dir" -type f -name "test_*.sh" \
                                   -not -name "$(basename "${BASH_SOURCE[0]}")" \
                                   -exec basename {} .sh \;)

    if (( ${#available_tests[@]} == 0 )); then
        log -w "No test scripts found in the 'tests/' directory."
        return 1
    fi
    log -d "Available tests: ${available_tests[*]}"

    local -a test_execution_list
    if (( ${#tests_to_run[@]} == 0 )) || [[ "${tests_to_run[*]}" == "all" ]]; then
        test_execution_list=("${available_tests[@]}")
    else
        test_execution_list=("${tests_to_run[@]}")
    fi

    log -d "Will run: ${test_execution_list[@]}"
    local overall_status=0
    local -a failed_suites
    for test_name in "${test_execution_list[@]}"; do
        local test_script_path="${test_dir}/${test_name}.sh"
        if [[ -f "$test_script_path" ]]; then
            source "$test_script_path"

            local suite_runner_func="run_suite"
            if declare -f "$suite_runner_func" > /dev/null; then
                log -Instr "Running test suite: ${test_name}..."

                "$suite_runner_func"
                local test_status=$?

                if (( test_status != 0 )); then
                    log -Error "Result for ${test_name}: FAIL"
                    overall_status=1
                    failed_suites+=("$test_name")
                else
                    log_always "Result for ${test_name}: PASS"
                fi
            else
                log -Error "Test script '$test_name' does not contain a 'run_suite' function."
                overall_status=1
                failed_suites+=("$test_name")
            fi
        else
            log -Error "Test script not found for '$test_name' at: $test_script_path"
            overall_status=1
            failed_suites+=("$test_name")
        fi
        log -MsgOnly "" # Add spacing between test suites
    done

    # --- Final Summary ---
    if (( overall_status == 0 )); then
        log -Always "✅ All tests passed."
    else
        log -Error "❌ Test run failed. Failing suites: ${failed_suites[*]}"
    fi
    return $overall_status

}

# --- Main Execution Guard ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi

