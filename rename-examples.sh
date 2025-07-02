#!/bin/bash

# # This script is a collection of live examples to demonstrate how to use the
# 'rename' command. It creates a temporary sandbox of files, runs various
# rename operations, shows the results, and then cleans up after itself.

# Create a temporary directory
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
TEMP_DIR=~/Downloads/tmp_$TIMESTAMP
SEPARATOR="*******************************"

# Make and Change to the temporary directory
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Create example files for demonstration
touch foo.txt foo1.txt file1.txt file2.txt file1.md file2.md "file with spaces.txt" "file1 copy.txt" part1_data.txt part2_data.txt

# Function to print and execute a command
execute_command() {
    echo -e "\n$SEPARATOR"
    echo -e "*  $1"
    echo -e "*  $2"
    eval $2
    ls -C
    echo -e " $SEPARATOR\n"
}

# 1. Replacing a Substring in Filenames
msg="Example 1: Replace 'foo' with 'bar' in filenames"
execute_command "$msg" "rename 's/foo/bar/' foo*.txt"

# 2. Changing File Extensions
msg="Example 2: Change .txt to .md"
execute_command "$msg" "rename 's/\\.txt\$/.md/' *.txt"

# 3. Prefixing Filenames
msg="Example 3: Add prefix 'new_' to all files"
execute_command "$msg" "rename 's/^/new_/' *"

# 4. Suffixing Filenames
msg="Example 4: Add suffix '_backup' before the file extension"
execute_command "$msg" "rename 's/(\\.[^.]+)\$/_backup\\1/' new*"

# 5. Converting Spaces to Underscores
msg="Example 5: Replace spaces with underscores in filenames"
execute_command "$msg" "find . -name '* *' -exec rename 's/ /_/' '{}' \;"

# 6. Using Positional Blocks: Swap parts of the filename
msg="Example 6: Swap 'part' and 'data' in filenames"
execute_command "$msg" "rename 's/(part)([0-9]+)(_data)/\$3\$2_\$1/' new*"

# 7. Removing all vowels from filenames
msg="Example 7: Remove all vowels from filenames"
execute_command "$msg" "rename 's/[aeiouAEIOU]//g' *"

# Change back to the original directory
cd -

# Clean up the temporary directory and files
echo -e "\nCleaning up example files and temporary directory..."
rm -rf "$TEMP_DIR"

echo "Done!"

