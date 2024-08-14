#!/bin/bash

# Define associative arrays
declare -A config
declare -A drives

# Initialize drive index
drive_index=0

# Read the configuration file
while IFS='=' read -r key value; do
    # Skip empty lines and comments
    [[ -z "$key" || $key =~ ^\# ]] && continue
    
    # Remove spaces around key and value
    key=$(echo $key | tr -d ' ')
    value=$(echo $value | tr -d ' ')

    # Check for section headers
    if [[ $key == \[*\] ]]; then
        case $key in
            "[general]")
                section="config"
                ;;
            "[drive]")
                section="drives[$drive_index]"
                ((drive_index++))
                ;;
        esac
    else
        # Assign value to the current section
        case $section in
            config)
                config["$key"]="$value"
                ;;
            drives\[*\])
                drives["${section}_$key"]="$value"
                ;;
        esac
        
        # Increment drive index after setting both uuid and name
        #if [[ ${key} == "name" && ${section} == "drives[$drive_index]" ]]; then
        #    ((drive_index++))
        #fi
    fi
done < "ykchrde.conf"

# Print out the parsed configuration
#echo "Config:"
#for key in "${!config[@]}"; do
#    echo "$key=${config[$key]}"
#done

#echo "Drives:"
#for i in "${!drives[@]}"; do    # Extract drive index and key from the composite key
#    IFS='_' read -r drive_index key <<< "$i"
#    echo "Drive $drive_index:"
#    echo "  $key=${drives[$i]}"
#done

#To access balue you use ${drives["drives[$index]_$key"]}
#echo "${drives[0]}"
#uuid=${drives["drives[0]_uuid"]}
#echo "UUID of the first drive: $uuid"

echo "$drive_index"


