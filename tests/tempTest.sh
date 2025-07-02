#!/usr/local/bin/bash
# set -x

# Source dependency files
source_dependencies() { # {{{
    local pathname_to_source=""
    local src_filename=""

    # Source file to get the thisFile fcn
    src_filename="lib_thisFile.sh"
    if [ -f "$(dirname "$0")/$src_filename" ]; then
        pathname_to_source="$(dirname "$0")/$src_filename"
        source "$pathname_to_source"
    else
        echo "[error] ${BASH_SOURCE[0]}: $src_filename library not found. Exiting."
        exit 1
    fi

    # Source logging library if available
    src_filename="lib_logging.sh"
    if [ -f "$(dirname "$0")/$src_filename" ]; then
        pathname_to_source="$(dirname "$0")/$src_filename"
        source "$pathname_to_source"

        # set_log_level "trace"
        set_log_level "debug"
        # set_log_level "info"

    else
        echo "$(thisFile): $src_filename library not found. Exiting."
        exit 1
    fi

} # }}}


source_dependencies 

test_logging_levels

