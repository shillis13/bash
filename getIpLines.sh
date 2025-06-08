#!/usr/local/bin/bash

BIN_DIR=""
AWK_SCRIPT="getIpLines.awk"
INPUT=""

function usage()
{
    echo "Usage:"
    echo "  $0 {INPUT_FILE}"
    echo "  $AWK_SCRIPT must be in same dir as $0"
}

if [[ $# == 1 ]];
then
    INPUT=$1
    BIN_DIR=`dirname $0`

    if [ ! -f $INPUT ];
    then
        echo -e "Input file $INPUT not found\n"
        usage 
        exit -1
    fi
else
    echo -e "No input file passed\n"
    usage
    exit -1
fi

if [ ! -f $BIN_DIR/$AWK_SCRIPT ];
then
    echo -e "Required script file $AWK_SCRIPT not found in $BIN_DIR \n"
    usage
    exit -1
fi

echo "awk -f $BIN_DIR/$AWK_SCRIPT $INPUT"
awk -f $BIN_DIR/$AWK_SCRIPT $INPUT

