#
# Part of the Bl (Bash library) suite
#
# Snippet of bash script to source include other bash libraries 
# while preventing the same file from being sourced multiple times
#
`
args=("${@}")

thisFile="${BASH_SOURCE[0]}"
# echo "Echo: Entered $thisFile..."

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

# *******************************************************************
# * {{{ @name: Bl_SourceLibs
# *
# * @desc:  Private-esque function to source the scripts necessary for 
# *         these functions
# *******************************************************************
Bl_SourceLibs() {
    if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi

    local args="${@}"
    srcFiles=()

    while [ -n "$1" ]; do
        if [ "$1" == "--srcFile" ]; then 
            # echo "Echo: $thisFile: \$1 = $1"
            shift 
            srcFiles+=("$1")
        fi
        shift
    done

    for file in "${srcFiles[@]}"; do 
        if [ -z "${SourcedFiles[$file]}" ]; then 
            if declare -f sourceFile &> /dev/null; then 
                sourceFile "$file" "${args[@]}"; 
            else 
                source "$file" "${args[@]}"; 
            fi
            SourcedFiles[$file]="$file"
        fi
    done
}
BlBase_SourceLibs() {
    local args=("${@}")
    filesToSrc=(bashLibrary_trace.sh bashLibrary_debug.sh bashLibrary_sources.sh bashLibrary_pkgFcns.sh bashLibrary_cmdArgs.sh) # <--- Edit this line or pass in files to source
    #

    # for f in $filesToSrc; do
    for file in "${filesToSrc[@]}"; do 
        args+=("--srcFile")
        args+=("$file")
    done
    Bl_SourceLibs "${args[@]}"
}
# }}}
# *******************************************************************

