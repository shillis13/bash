#!/usr/local/bin/bash

function usage()
{
    echo "$0 {file}"
    echo
}

INPUT=$1

INDENT="  "

IP_REGEX='(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)'
SORT_UNIQUE="sort | uniq -c | sort -n"
AWK_MATCH1="match(\$0, /${IP_REGEX}/)"
AWK_CMD1="{print substr(\$0, RSTART, RLENGTH)}"

AWK_CMD2="{print substr(\$0, RSTART, RLENGTH)}"
AWK_CMD2="{print \"$INDENT\" \$0}"


c=0
for i in `awk "${AWK_MATCH1} ${AWK_CMD1}" $INPUT | sort | uniq -c | sort -n `
do
    if [ $(expr $c % 2) == 0 ]
    then
        echo -n "$i "
    else
        echo -e "${i}\n{{{"
        #echo "awk '/$i/ {print \"$INDENT\" \$0}' $INPUT"
        awk "/$i/ {print \"$INDENT\" \$0}" $INPUT
        echo  "}}}"
    fi
    ((c++))
done
