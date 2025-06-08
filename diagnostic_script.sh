#!/usr/bin/env bash

# Script to diagnose terminal title change and file descriptor leaks

echo "Starting Diagnostic Script"
echo "Current Terminal Title: $TERM"

# Function to update terminal title
update_terminal_title() {
    echo -ne "\033]0;Diagnostic Script\007"
}

# Test changing terminal title
echo "Testing terminal title change..."
update_terminal_title
sleep 2

# Test for file descriptor leak
echo "Testing for file descriptor leak..."
for i in {1..100}; do
    exec {fd}>/tmp/testfile
    echo "Opened file descriptor: $fd"
    sleep 1
    exec {fd}>&-
done

# Check if terminal title changes back automatically
echo "Check if the terminal title changes back automatically after script ends"
