#!/usr/bin/bash

declare -A config
declare -A drives
declare -A yubikeys

# Initialize drive index
drive_index=0
yubikey_index=0

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
            "[yubikey]")
                section="yubikeys[$yubikey_index]"
                ((yubikey_index++))
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
            yubikeys\[*\])
                yubikeys["${section}_$key"]="$value"
                ;;

        esac

    fi
done < "/etc/ykchrde.conf"

drive_count=$drive_index
yubikey_count=$yubikey_index

serial=$(ykinfo -s | tr -d 'serial: ')
while [[ -z $serial ]]; do
    # echo "No Yubikey inserted"
    # echo "Press ctrl+c to exit"
    sleep 1
    serial=$(ykinfo -s | tr -d 'serial: ')
done
yubikey_slot=1
for (( i=0; i<$yubikey_count; i++))
do
    if [[ "$serial" == "${yubikeys["yubikeys[$i]_serial"]}" ]]; then
        yubikey_slot=${yubikeys["yubikeys[$i]_slot"]}
        break
    fi
done
echo "$yubikey_slot"
