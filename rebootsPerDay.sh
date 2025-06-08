#!/usr/local/bin/bash

# Define the default number of days to check
days=14

# Parse command line options
while getopts "d:" opt; do
  case $opt in
    d)
      days=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Get the current date
current_date=$(date +%Y-%m-%d)

# Get the date N days ago
start_date=$(date -d "$current_date - $days days" +%Y-%m-%d)

# Initialize an empty array to store the reboots per day
declare -A reboots_per_day

# Iterate through the last N days
for i in $(seq 0 $days); do
    # Get the date of the current iteration
    date=$(date -d "$start_date + $i days" +%Y-%m-%d)

    # Count the number of reboots on the current date
    reboots=$(last -R | grep "$date" | grep "reboot" | wc -l)

    # Store the number of reboots in the array
    reboots_per_day["$date"]=$reboots
done

# Print the reboots per day
for date in "${!reboots_per_day[@]}"; do
    echo "$date: ${reboots_per_day[$date]}"
done

