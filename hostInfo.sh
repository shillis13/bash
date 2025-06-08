#!/usr/local/bin/bash

# Default values for parameters
current_datetime=$(date +%Y-%m-%d-%H:%M:%S)
disk_partition="/dev/vda1"

# Function to print usage
usage() {
  echo "Usage: $0 [-d <disk partition>] [-h]"
  echo "  -d <disk partition>  specify the disk partition to check, default is ${disk_partition}"
  echo "  -h|--help|usage      display this help and exit"
  echo "  -m <mem variable?>	Display info on memory installed and current usage"
  echo "  -c <cpu variable?>	Display info on cpus installed and current usage"
  echo ""
  echo "Examples:"
  echo "  $0 -h"
  exit 1
}

# Parse command line options
while getopts "d:h" opt; do
  case $opt in
    d)
      disk_partition=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    esac
done

# Get Linux version
linux=$(lsb_release -a)

# Docker version
dockerv=$(docker version)

# Snap version
snapv=$(snap version)

# Rocket.Chat version
rchatv=$(snap info rocketchat-server)

# MongoDb version
mongov=$(snap info mongodb)

# Get the server uptime
uptime=$(uptime -p)

# Get the load averages
load_average=$(cat /proc/loadavg)

# Get the CPU usage
cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Get the memory usage
memory_usage=$(free -m --human | awk 'NR==2{printf "%.2f%%\t\t", $3*100/$2 }')

# Get the disk usage
disk_usage=$(df -h $disk_partition | awk '$NF=="/"{printf "%s\t\t", $5}')

# Get the network usage
network_rx=$(ifconfig eth0 | grep "RX bytes" | cut -d: -f2 | awk '{ print $1 }')
network_tx=$(ifconfig eth0 | grep "TX bytes" | cut -d: -f3 | awk '{ print $1 }')

# Get the resource usage
resource_usage=$(sar --human -u 1 1)

# Get the disk I/O statistics
#disk_io_statistics=$(iostat --human -d -x $disk_partition 1 1)
disk_io_statistics=$(iostat --human -d | egrep -v "^loop")

# Get the CPU statistics
cpu_statistics=$(mpstat -u 1 1)
cpu_statistics2=$(iostat -c --human)
cpu_info=$(cat /proc/cpuinfo | egrep "processor|cpu MHz|cache size")

# Get the memory and swap statistics
memory_swap_statistics=$(vmstat --unit M 1 1)

# Get the network statistics
network_statistics=$(netstat -s)

# Get the process statistics
process_statistics=$(pidstat --human -dl -r -u 1 1)

# Print the statistics
echo "Date and Time: $current_datetime"
echo -e "\nUptime: $uptime"
echo -e "\nLoad Average: $load_average"
echo -e "\nCPU Info: \n$cpu_info%"
echo -e "\nCPU Usage: $cpu_usage%"
echo -e "\nCPU Statistics: (mpstat)"
echo -e "$cpu_statistics"
echo -e "\nCPU Statistics: (iostat)"
echo -e "$cpu_statistics2"
echo -e "\nMemory Usage: $memory_usage"
echo -e "\nMemory and Swap Statistics:"
echo -e "\n$memory_swap_statistics (MB)"
echo -e "\nDisk Usage: $disk_usage"
echo -e "\nDisk I/O Statistics:"
echo -e "$disk_io_statistics"
echo -e "\nNetwork Usage (RX/TX): $network_rx / $network_tx"
echo -e "\nResource Usage:"
echo -e "$resource_usage"
echo -e "Network Statistics:"
echo -e "\nProcess Statistics:"
echo "$process_statistics"
