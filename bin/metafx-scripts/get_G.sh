#!/bin/bash
# Utility for detecting greatest G value, such that the number of unique k-mers is more than 100000

a=$(grep "of them is good" ${1} | grep -o -E ", [0-9']+ \(")
a=$(echo "$a" | sed "s/'//g" | grep -o -E "[0-9]+")

if [[ -z "$a" ]]; then
    exit 1
fi

cnt=${2}
for line in ${a//\\n/ }
do
    if [[ $line -gt 100000 ]]; then
        cnt=$((cnt+1))
    else
        echo $cnt
        exit 0
    fi
done
echo $(( $cnt - 1 ))
exit 0
