#!/usr/local/bin/bash

# Check if both parameters are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 <path_to_dmg> <path_to_passwords>"
  exit 1
fi

dmg_path="$1"
password_file="$2"
delay_after_fail=60  # Delay in seconds
fail_count=0
max_fails_before_sleep=3  # Number of fails before triggering the sleep
output=""
success=false
debug=""
# debug="-debug"

while read -r password; do
    # if [ -n "$password" ] && [ -z "${password// }" ]; then
    if [ "x${password}" != "x" ]; then
        if [[ ${password:0:1} != "#" ]]; then

            echo "Trying password: $password"
            echo "echo -n "$password" | hdiutil attach "$dmg_path" -stdinpass"
            # output=$(echo -n "$password" | hdiutil attach "$dmg_path" -stdinpass ${debug} 2>&1 )

            # Redirect the entire loop's output to the 'output' variable
            output=$(
            { echo -n "$password" | hdiutil attach "$dmg_path" -stdinpass ${debug}; } 2>&1
                )

            # echo "hdiutil attach -imageKey "$password" "$dmg_path" "
            # hdiutil attach -imageKey "$password" "$dmg_path"

            if [ "x${output}" != "x" ]; then
                echo "<output> ${output} </output>"
            fi

            if [ $? -eq 0 ]; then
                # Sometimes a zero return still has an error
                if [[ ${output} != *error* ]]; then
                    success=true
                fi
            fi

            if $success; then
                echo "Successfully mounted the DMG with password: $password"
                break
            else
                echo "Failed with password: $password"
                ((fail_count++))

                if [ $fail_count -ge $max_fails_before_sleep ]; then
                    echo "Reached maximum number of attempts. Sleeping for $delay_after_fail seconds."
                sleep $delay_after_fail
                fail_count=0  # Reset the fail count
                fi
            fi
        else
            if [ "x${debug}" == "x" ]; then
                echo -n "Skipping comment: "
                echo "${password}"
            fi
        fi
    else
        echo -n "password not passing ... is it set?  PW: "
        echo "${password}"
    fi

    done < "$password_file"

