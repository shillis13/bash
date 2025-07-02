#!/usr/local/bin/bash
# set -x

args=("${@}")

# thisFile="${BASH_SOURCE[0]}"
thisFile="bashLibrary_pkgFcns.sh"
# Db "* Echo: Entered $thisFile..."

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

##################################
#
#   Functions:
#       - declare packages
#       - add_package
#       - parse_pkg_args
#   
#   Source baseLibrary_cmdArgs.sh
##################################
# if [ -z "${packages}" ]; then declare -A -g packages; packages[0]="0"; fi

# ****************************************************
# {{{ @name: add_package <name> <default_install> <flag> <usage> <function_name>
# *
# * Add package spec to array variable $packages
# ****************************************************
add_package() {
    Db_Entry

    if [ -z "${packages}" ]; then declare -A -g packages; fi

    local name=$1
    local default_install=$2
    local flag=$3
    local usage=$4
    local function_name=$5
    local install="$default_install"

    local -i numPkgs=${#packages[@]}

    #for package in "${packages[@]}"; do
    # echo "Echo: packages[$numPkgs]=$name:$default_install:$install:$flag:$usage:$function_name"
    packages[$numPkgs]="$name:$default_install:$install:$flag:$usage:$function_name"

    # Verify that the provided function_name matches an existing function
    if [ ! command -v "$function_name" &> /dev/null ]; then
        echo "Pkg Error: no matching function exists: ${function_name}"
        exit 1
    fi

}
# }}}
# ****************************************************

# ****************************************************
# * {{{ Example main for testing and example
# *
# ****************************************************
example_main() {
    Db_Entry
    local args=("$@")
    add_package "shellcheck" true "--shellcheck" "\t--shellcheck\tinstall shellcheck" "test_install_shellcheck"
    add_package "sysstat" false "--sysstat" "\t--sysstat\tinstall sysstat" "test_install_sysstat"

    run_command pkgs_main "${args[@]}"

    # parse_pkg_args "${args[@]}"
    # parse_pkg_args "${args[@]}"
    # run_packages

    exit 0
}
# }}}
# ****************************************************

# ****************************************************
# * {{{ pkgs_main
# *
# * A main that a pkgs using script can all that will
# * parse and execute
# ****************************************************
pkgs_main() {
    local args=("$@")
    run_command parse_pkg_args "${args[@]}"
    run_command run_packages
}
# }}}
# ****************************************************

# ****************************************************
# * {{{ @name: run_packages
# *
# ****************************************************
run_packages() {
    Db_Entry
    pkgsPrint=$(print_pkgs)
    # Db "Packages: $pkgsPrint"
    local -i numPkgs=${#packages[@]}
    local -i idx=0

    # for package in "${packages[@]}"; do
    while (( $idx < $numPkgs )); do
        package="${packages[$idx]}"
        IFS=':' read -r -a package_info <<< "$package"

        # echo "\${package_info[2]}=${package_info[2]}   SMH"
        if [[ ${package_info[2]} == "true" ]]; then
            # echo "Echo: run_command ${package_info[5]}"
            run_command ${package_info[5]}
        fi

        idx+=1
    done
}
# }}}
# ****************************************************

# ****************************************************
# {{{ @name: parse_pkg_args
# *
# * Parse command line args
# *
# ****************************************************
parse_pkg_args() {
    Db_Entry
    local args=("$@")

    i=0
    # found=false

    while [[ $# -gt 0 ]]
    do
        key="$1"
        # echo "Echo: $key"

        for j in "${!packages[@]}"; do
            IFS=':' read -r -a package_info <<< "${packages[$j]}"
            if [[ ${package_info[3]} == $key ]]; then
                packages[$j]="${package_info[0]}:${package_info[1]}:true:${package_info[3]}:${package_info[4]}:${package_info[5]}"
                # found=true
            fi
        done

        # Print the packages
        if [[ "$1" == "-p" || "$1" == "--print" ]]; then
            Db_Info "Print pkg definitions"
            print_pkgs
        fi

        # Print the usage
        if [[ "$1" == "-h" || "$1" == "--help" ]]; then
            Db_Info "Print usage:"

            usage_functions=($(Db_GetFuncsByName "usage"))
            for u in "${usage_functions[@]}"; do
                echo "Echo: $u"
                eval "${u}"
            done

            exit 0
        fi

        # Set install for all packages to true
        if [[ "$1" == "--all" ]]; then
            Db_Info "Install all pkgs"
            for j in "${!packages[@]}"; do
                IFS=':' read -r -a package_info <<< "${packages[$j]}"
                # packages[$j]="${package_info[0]}:true:${package_info[2]}:${package_info[3]}:${package_info[4]}:${package_info[5]}"
                packages[$j]="${package_info[0]}:${package_info[1]}:true:${package_info[3]}:${package_info[4]}:${package_info[5]}"
            done
            # found=true
        fi

        # Set install for all packages to false
        if [[ "$1" == "--none" ]]; then
            Db_Info "Install no  pkgs"
            for j in "${!packages[@]}"; do
                IFS=':' read -r -a package_info <<< "${packages[$j]}"
                # packages[$j]="${package_info[0]}:false:${package_info[2]}:${package_info[3]}:${package_info[4]}:${package_info[5]}"
                packages[$j]="${package_info[0]}:false:false:${package_info[3]}:${package_info[4]}:${package_info[5]}"
            done
            # found=true
        fi

        # if [[ $found == false ]]; then
            # echo "Error: invalid option '$key'"
            # exit 1
        # fi

        shift
        # found=false
    done

    run_command parse_args_for_run_command "${args[@]}"

    return 0
}
# }}}
# ****************************************************

# ****************************************************
# {{{ print_pkgs
# *
# * Print the package definitions
# *
# ****************************************************
print_pkgs() {
    Db_Entry

    # determine maximum column widths
    local -i max_name_width=0
    local -i max_default_width=0
    local -i max_install_width=0
    local -i max_flag_width=0
    local -i max_usage_width=0
    local -i max_fcn_width=0

    local -i numpkgs=${#packages[@]}
    local -i idx=0
    
    #for package in "${packages[@]}"; do
    while (( $idx < $numpkgs )); do
        package="${packages[$idx]}"
        IFS=':' read -r -a package_info <<< "$package"
        (( ${#package_info[0]} > max_name_width )) && max_name_width=${#package_info[0]}
        (( ${#package_info[1]} > max_default_width )) && max_default_width=${#package_info[1]}
        (( ${#package_info[2]} > max_install_width )) && max_install_width=${#package_info[2]}
        (( ${#package_info[3]} > max_flag_width )) && max_flag_width=${#package_info[3]}
        (( ${#package_info[4]} > max_usage_width )) && max_usage_width=${#package_info[4]}
        (( ${#package_info[5]} > max_fcn_width )) && max_fcn_width=${#package_info[5]}

        idx+=1
    done

    idx=0
    # print aligned columns
    # for package in "${packages[@]}"; do
    while (( idx < numpkgs )); do
        package="${packages[$idx]}"
        IFS=':' read -r -a package_info <<< "$package"
        printf "name:    %-${max_name_width}s " "${package_info[0]}"
        printf "default: %-${max_default_width}s " "${package_info[1]}"
        printf "install: %-${max_install_width}s " "${package_info[2]}"
        printf "flag:    %-${max_flag_width}s " "${package_info[3]}"
        printf "usage:   %-${max_usage_width}s " "${package_info[4]}"
        printf "fcn:     %-${max_fcn_width}s\n" "${package_info[5]}"

        idx+=1
    done
}

# ******************************
# {{{ print_pkgs_old() 
print_pkgs_old() {
    Db_Entry
    echo "Packages:"
    for package in "${packages[@]}"; do
        IFS=':' read -r -a package_info <<< "$package"

    	# packages+=("$name:$default_install:$install:$flag:$usage:$function_name")

        echo -en "name:    ${package_info[0]} \t"
        echo -en "default: ${package_info[1]} \t"
        echo -en "install: ${package_info[2]} \t"
        echo -en "flag:    ${package_info[3]} \t"
        echo -en "usage:   ${package_info[4]} \t"
        echo -en "fcn: 	   ${package_info[5]} \n"
    done
}
# }}}
# ****************************************************
# }}}
# ****************************************************

# ****************************************************
# {{{ tests
# *
# ****************************************************
test_install_shellcheck() {
    run_command on_err_cont echo "test_install_spellcheck()"
}

test_install_sysstat() {
    run_command on_err_cont echo "test_install_sysstat()"
}
# }}}
# ****************************************************

# example_main $@
