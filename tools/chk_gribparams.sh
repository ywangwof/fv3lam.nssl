#!/bin/bash

input1="params_grib2_tbl_new.2019"
input2="params_grib2_tbl_2022"
while IFS= read -r line
do
    if [[ ${line:0:1} == '!' ]]; then
        continue
    fi
    elements=($line)
    #echo -n "${elements[4]}"

    found=0
    while IFS= read -r line2
    do
        if [[ ${line2:0:1} == '!' ]]; then
            continue
        fi
        elements2=($line2)
        #echo "${elements2[4]}"
        if [[ ${elements[4]} == ${elements2[4]} ]]; then
            found=1
            break
        fi
    done < "$input2"

    if [[ $found -lt 1 ]]; then
        echo "${elements[4]} NOT in \"$input2\""
    #else
    #    echo "  found"
    fi
done < "$input1"

exit 0