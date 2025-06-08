# Test file I/O performance under stress

# Set default maximum file size in megabytes
max_size=100

# Set default maximum number of iterations
max_iterations=10000

# Set default iostat log file
iostat_log="iostat.log"

# Get the OS type because stat options are different
osType=$(uname)
if [ x$osType == "xDarwin" ]
then 
    # Homebrew coreutils provides a stat similar to Linux
    # The normal stat uses different options
    which stat | egrep gnubin 2>&1 > /dev/null
    if [ $? -eq 1 ]
    then
        # Stat is not gnubin's
        statCmd="stat -f %z"
    else
        # Stat is gnubin's
        statCmd="stat -c %s"
    fi

    # Check if homebrew's gdate is installed
    gdate 2>&1 > /dev/null
    if [ $? -eq 0 ]
    then
        dateCmd="gdate +%s%N"
    else
        dateCmd="date +'%s * 1000 + %-N / 1000000"
    fi
else if [ x$osType == "xLinux" ]
    then
        statCmd="stat -c %s"
        dateCmd="date +%s%N"
    else
        echo "Warning: Unrecognized OS type: $osType - defaulting to Linux"
        statCmd="stat -c %s"
        dateCmd="date +%s%N"
    fi
fi

# Parse command line arguments
while getopts ":m:i:l:" opt; do
  case $opt in
    m)
      max_size="$OPTARG"
      ;;
    i)
      max_iterations="$OPTARG"
      ;;
    l)
      iostat_log="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

min() {
    echo "$@" | tr ' ' '\n' | sort -g | head -n 1
}
max() {
    echo "$@" | tr ' ' '\n' | sort -rg | head -n 1
}
equals()
{
    minVal=$(min $@)
    maxVal=$(max $@)
    if [ $minVal == $maxVal ]
    then
        echo 1
    else 
        echo 0
    fi
}

# Create the test files with some initial text
echo "This is file 1" > file1.txt
echo "This is file 2" > file2.txt

# Check if the files were created
if [ -f file1.txt ] && [ -f file2.txt ]; then
  echo "file1.txt and file2.txt were created successfully"
else
  echo "Unable to create one or more of the test files"
  exit 1
fi

# Start iostat in the background to capture CPU and disk utilization reports every 5 seconds
iostat -c 5 >> $iostat_log &

# Measure the time it takes to append the contents of one file to the other and vice versa until they reach the maximum size or a certain number of iterations
reads=0
writes=0
bytes_read=0
bytes_written=0
min_read_rate=0
max_read_rate=0
min_write_rate=0
max_write_rate=0
append_start=$($dateCmd)
size1=0
size2=0
iterations=0

while [ $size1 -le $max_size ] && [ $size2 -le $max_size ] && [ $iterations -lt $max_iterations ]; do
  # Append the contents of file1.txt to file2.txt
  cat file1.txt >> file2.txt
  writes=$(($writes + 1))
  bytes_written=$(($bytes_written + $($statCmd "file2.txt")))
  
  # Append the contents of file2.txt to file1.txt
  cat file2.txt >> file1.txt
  writes=$(($writes + 1))
  bytes_written=$(($bytes_written + $($statCmd "file1.txt")))
  
  # Check the sizes of the files
  size1=$($statCmd "file1.txt")
  size1=$(($size1 / 1000000))
  size2=$($statCmd "file2.txt")
  size2=$(($size2 / 1000000))
  iterations=$(($iterations + 1))
  
  # Increment the read and write counters
  reads=$(($reads + 2))
  bytes_read=$(($bytes_read + $($statCmd "file1.txt") + $($statCmd "file2.txt")))
  
  # Determine 
  append_end=$($dateCmd)
  append_time=$((($append_end - $append_start)/1000000))

  # Calculate the read and write rates
  divisor=`echo "scale = 3; $append_time / 1000" | bc`
  read_rate=`echo "scale = 3; $bytes_read / $divisor" | bc`
  write_rate=`echo "scale = 3; $bytes_written / $divisor" | bc`
  #write_rate=$(($bytes_written / ($append_time / 1000)))
  
  # Update the minimum and maximum read and write rates
  #if [ $read_rate -lt $min_read_rate ] || [ $min_read_rate -eq 0 ]; then
  #if [  $min_read_rate -eq 0 ]; then
  if [  $(equals $min_read_rate 0) ]; then
    min_read_rate=$read_rate
  else
    min_read_rate=$(min $min_readrate $read_rate)
  fi
  max_read_rate=$(max $max_read_rate $read_rate)

  if [  $(equals $min_write_rate 0) ]; then
    min_write_rate=$write_rate
  else
    min_write_rate=$(min $min_writerate $write_rate)
  fi
  max_write_rate=$(max $max_write_rate $write_rate)

done

append_end=$($dateCmd)
append_time=$((($append_end - $append_start)/1000000))
echo "Time to append the contents of file1.txt to file2.txt and vice versa until they reached $max_size megabytes or $max_iterations iterations: $append_time milliseconds"
echo "Total reads: $reads"
echo "Total writes: $writes"
echo "Total bytes read: $bytes_read"
echo "Total bytes written: $bytes_written"
echo "Minimum read rate: $min_read_rate bytes/sec"
echo "Maximum read rate: $max_read_rate bytes/sec"
echo "Minimum write rate: $min_write_rate bytes/sec"
echo "Maximum write rate: $max_write_rate bytes/sec"


