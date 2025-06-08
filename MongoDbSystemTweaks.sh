#!/usr/local/bin/bash
# set -x

# ###################################################################
# # @file: mongoDbSystemTweaks.sh
# #
# # @dependencies: bashLibrary_base.sh (and its dependencies)
# ###################################################################

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then args=("${@:1}")
else args=("${@}"); fi

thisFile="${BASH_SOURCE[0]}"

# Two lines to help prevent duplicate sourcing
if [ -z "${SourcedFiles}" ]; then declare -A -g SourcedFiles; SourcedFiles[0]="0"; fi
if [ -n "${SourcedFiles[$thisFile]}" ]; then return 1; else SourcedFiles[$thisFile]="$thisFile"; fi

source bashLibrary_base.sh "${args[@]}" "--debugLevel" "7"

# *******************************************************************
# * {{{ define_pkgs_mongoSysTweaks
# *
# *******************************************************************
define_pkgs_mongoSysTweaks() {
    # add_package <name> <default_install> <install> <flag> <usage> <function_name>
    add_package "getMDbSysValues" true "--getMDbSysValues" "\t--getMDbSysValues\tprint the system values important to MongoDb" "get_mongodb_perf_tweaks"
    add_package "setMDbSysValues" false "--setMDbSysValues" "\t--setMDbSysValues\tSet the system values important to MongoDb" "set_mongodb_perf_tweaks"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ main
# *
# *******************************************************************
main() {
    local args=("$@")
    run_command define_pkgs_mongoSysTweaks

    run_command pkgs_main "${args[@]}"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ @name: get_mongodb_perf_tweaks 
# *
# *******************************************************************
get_mongodb_perf_tweaks {

    # ulimits
    current_ulimit_nofile=$(ulimit -n)
    current_ulimit_nproc=$(ulimit -u)
    desired_ulimit_nofile=64000
    desired_ulimit_nproc=32000
    echo "Current ulimit nofile: $current_ulimit_nofile (desired: $desired_ulimit_nofile)"
    echo "Current ulimit nproc: $current_ulimit_nproc (desired: $desired_ulimit_nproc)"

    # swappiness
    current_swappiness=$(cat /proc/sys/vm/swappiness)
    desired_swappiness=1
    echo "Current swappiness: $current_swappiness (desired: $desired_swappiness)"

    # MongoDB connections
    current_maxConns=$(grep "^maxConns" /etc/mongodb.conf | awk '{print $2}')
    desired_maxConns=64000
    echo "Current MongoDB max connections: $current_maxConns (desired: $desired_maxConns)"

    # journal size
    current_journalSize=$(grep "^journalSize" /etc/mongodb.conf | awk '{print $2}')
    desired_journalSize=2048
    echo "Current MongoDB journal size: $current_journalSize (desired: $desired_journalSize)"

    # storageEngine
    current_storageEngine=$(grep "^storageEngine" /etc/mongodb.conf | awk '{print $2}')
    desired_storageEngine=wiredTiger
    echo "Current MongoDB storageEngine: $current_storageEngine (desired: $desired_storageEngine)"
}
# }}}
# *******************************************************************

# *******************************************************************
# * {{{ @name: set_mongodb_perf_tweaks
# *
# *******************************************************************
set_mongodb_perf_tweaks {
  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo"
    return
  fi

  dateStr=$(date "+%Y-%m-%d %T")
  oldVal="# Old Value - smg ${dateStr}"
  addMsg="# Added by set_mongodb_performance (smg) script ${dateStr}"

  # Increase ulimits
  if ! grep -q "soft    nofile    64000" /etc/security/limits.conf; then
    if grep -q "^*.*soft.*nofile" /etc/security/limits.conf; then
      sed -i "/^*.*soft.*nofile/ s/^/${oldVal}: /" /etc/security/limits.conf
      sed -i "${oldVal}:/a\*    soft    nofile    64000" /etc/security/limits.conf
    else
      echo "${addMsg}" >> /etc/security/limits.conf
      echo "*    soft    nofile    64000" >> /etc/security/limits.conf
    fi
  fi
  if ! grep -q "hard    nofile    64000" /etc/security/limits.conf; then
    if grep -q "^*.*hard.*nofile" /etc/security/limits.conf; then
      sed -i "/^*.*hard.*nofile/ s/^/${oldVal}: /" /etc/security/limits.conf
      sed -i "${oldVal}:/a\*    hard    nofile    64000" /etc/security/limits.conf
    else
      echo "${addMsg}" >> /etc/security/limits.conf
      echo "*    hard    nofile    64000" >> /etc/security/limits.conf
    fi
  fi
  if ! grep -q "soft    nproc    32000" /etc/security/limits.conf; then
    if grep -q "^*.*soft.*nproc" /etc/security/limits.conf; then
      sed -i "/^*.*soft.*nproc/ s/^/${oldVal}: /" /etc/security/limits.conf
      sed -i "${oldVal}:/a\*    soft    nproc    32000" /etc/security/limits.conf
    else
      echo "${addMsg}" >> /etc/security/limits.conf
      echo "*    soft    nproc    32000" >> /etc/security/limits.conf
    fi
  fi
  if ! grep -q "hard    nproc    32000" /etc/security/limits.conf; then
    if grep -q "^*.*hard.*nproc" /etc/security/limits.conf; then
      sed -i "/^*.*hard.*nproc/ s/^/${oldVal}: /" /etc/security/limits.conf
      sed -i "${oldVal}:/a\*    hard    nproc    32000" /etc/security/limits.conf
    else
      echo "${addMsg}" >> /etc/security/limits.conf
      echo "*    hard    nproc    32000" >> /etc/security/limits.conf
    fi
  fi
  if ! grep -q "soft    memlock    unlimited" /etc/security/limits.conf; then
    if grep -q "^*.*soft.*memlock" /etc/security/limits.conf; then
      sed -i "/^*.*soft.*memlock/ s/^/${oldVal}: /" /etc/security/limits.conf
      sed -i "${oldVal}:/a\*    soft    memlock    unlimited" /etc/security/limits.conf
    else
      echo "${addMsg}" >> /etc/security/limits.conf
      echo "*    soft    memlock    unlimited" >> /etc/security/limits.conf
    fi
  fi
  if ! grep -q "hard    memlock    unlimited" /etc/security/limits.conf; then
    if grep -q "^*.*hard.*memlock" /etc/security/limits.conf; then
      sed -i "/^*.*hard.*memlock/ s/^/${oldVal}: /" /etc/security/limits.conf
      sed -i "${oldVal}:/a\*    hard    memlock    unlimited" /etc/security/limits.conf
    else
      echo "${addMsg}" >> /etc/security/limits.conf
      echo "*    hard    memlock    unlimited" >> /etc/security/limits.conf
    fi
  fi

  # set swappiness to 1
  if ! grep -q "vm.swappiness = 1" /etc/sysctl.conf; then
    if grep -q "^vm.swappiness" /etc/sysctl.conf; then
      sed -i "/^vm.swappiness/ s/^/${oldVal}: /" /etc/sysctl.conf
      sed -i "${oldVal}:/a\vm.swappiness = 1" /etc/sysctl.conf
    else
      echo "${addMsg}" >> /etc/sysctl.conf
      echo "vm.swappiness = 1" >> /etc/sysctl.conf
    fi
    sysctl -w vm.swappiness=1
  fi

  # increase the number of MongoDB connections
  if ! grep -q "maxConns: 64000" /etc/mongodb.conf; then
    if grep -q "^maxConns" /etc/mongodb.conf; then
      sed -i "/^maxConns/ s/^/${oldVal}: /" /etc/mongodb.conf
      sed -i "${oldVal}:/a\${addMsg}\nmaxConns: 64000" /etc/mongodb.conf
    else
      echo "${addMsg}" >> /etc/mongodb.conf
      echo "maxConns: 64000" >> /etc/mongodb.conf
    fi
  fi

  # increase journaling size
  if ! grep -q "journalSize: 2048" /etc/mongodb.conf; then
    if grep -q "^journalSize" /etc/mongodb.conf; then
      sed -i "/^journalSize/ s/^/${oldVal}: /" /etc/mongodb.conf
      sed -i "${oldVal}:/a\${addMsg}\njournalSize: 2048" /etc/mongodb.conf
    else
      echo "${addMsg}" >> /etc/mongodb.conf
      echo "journalSize: 2048" >> /etc/mongodb.conf
    fi
  fi
  
  # Enable WiredTiger
  if ! grep -q "storageEngine: wiredTiger" /etc/mongodb.conf; then
    if grep -q "^storageEngine" /etc/mongodb.conf; then
      sed -i "/^storageEngine/ s/^/${oldVal}: /" /etc/mongodb.conf
      sed -i "${oldVal}:/a\${addMsg}\nstorageEngine: wiredTiger" /etc/mongodb.conf
    else
      echo "${addMsg}" >> /etc/mongodb.conf
      echo "storageEngine: wiredTiger" >> /etc/mongodb.conf
    fi
  fi
  
  # Echo the content of the mongodb.conf file
  echo "mongodb.conf: "
  cat /etc/mongodb.conf
}
# }}}
# *******************************************************************

main ${args[@]}

