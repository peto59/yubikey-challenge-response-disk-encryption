#!/bin/bash

#################################################CONFIG READ##############################################################
# Define associative arrays
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
done < "ykchrde.conf"

drive_count=$drive_index
yubikey_count=$yubikey_index

# Print out the parsed configuration
#echo "Config:"
#for key in "${!config[@]}"; do
#    echo "$key=${config[$key]}"
#done
#
#echo "Drives:"
#for i in "${!drives[@]}"; do
#    # Extract drive index and key from the composite key
#    IFS='_' read -r drive_index key <<< "$i"
#    echo "Drive $drive_index:"
#    echo "  $key=${drives[$i]}"
#done

#To access value you use ${drives["drives[$index]_$key"]}
#To access value you use ${yubikeys["yubikeys[$index]_$key"]}
#################################################################################END CONFIG READ#################################################################

function print_help() {
    echo "usage: ykchrde ACTION OPTIONS"
    echo
    echo "ACTIONS:"
    echo "open - opens device, if used without parameters it will try to open all devices from ykchrde.conf"
    echo "enroll - enrolls new key to device"
    echo "enroll-additional - enrolls new key to device but uses yubikey to get old password. Use this to enroll another yubikey after you've killed interactive key slot"
    echo
    echo "OPTIONS:"
    echo "-d|--device - specifies device on which to take action. Format: /dev/<device>. Ignored if -u|--uuid is set."
    echo "-u|--uuid - specifies device on which to take action through UUID of partition or disk"
    echo "-n|--name - maps device to this name (/dev/mapper/<name>). Ignored if action is enroll."
    echo "-h|--help - prints this menu"
}

function convert_user_password() {
    local password=$1
    local uuid=$2
    echo -n "$password|$uuid" | sha512sum | awk '{print $1}' | ykchalresp -$yubikey_slot -i - | sha512sum | awk '{print $1}'
}

function enroll_key() {
    local uuid=$1
    local old_password=$2
    local new_password=$3
    expect <(
    cat <<EXPECTSCRIPT
    log_user 0
    set timeout -1
    spawn cryptsetup luksAddKey /dev/disk/by-uuid/$uuid
    expect {
        "Enter any existing passphrase: " {
            send "$old_password\n"
            expect {
                "Enter new passphrase for key slot: " {
                    send "$new_password\n"
                    expect {
                        "Verify passphrase: " {
                            send "$new_password\n"
                            expect {
                                eof {
                                    send_user "Added key\n"
                                    exit 0
                                }
                                "Passphrases do not match." {
                                    send_user "Something went wrong Code:3\n"
                                }
                                default {
                                    #set unmatched_output \$expect_out(buffer) # Capture the output leading to default case
                                    send_user "Something went wrong Code:2\nTriggered by: \$expect_out(buffer)\n"
                                    send_user "Something went wrong Code:2\n"
                                    exp_continue
                                }
                            }
                        }
                        default {
                            send_user "Something went wrong Code:1\n"
                        }
                    }
                }
                default {
                    send_user "Invalid old password\n"
                }
            }
        }
        default {
            send_user "Insufficient priviledge to run cryptsetup, try with sudo\n"
        }
    }
EXPECTSCRIPT
  )
}

function open() {
    local uuid=$1
    local password=$2
    local mapping=$3
    state=$(expect <(
    cat <<EXPECTSCRIPT
    log_user 0
    set timeout -1
    spawn cryptsetup open /dev/disk/by-uuid/$uuid $mapping
    expect {
        "Enter passphrase for /dev/disk/by-uuid/$uuid: " {
            send "$password\n"
            expect {
                "No key available with this passphrase." {
                    send_user "Invalid password\n"
                    exit 1
                }
                eof {
                    send_user "Device opened\n"
                    exit 0
                }
                default {
                    send_user "Something went wrong\n"
                }
            }
        }
        default {
            send_user "Insufficient priviledge to run cryptsetup, try with sudo\n"
        }
    }
EXPECTSCRIPT
))
echo "$state"
}

##########################################################################YUBIKEY SLOT############################################
serial=$(ykman list --serials | tr '\n' ':' | cut -d ':' -f1)
while [[ -z $serial ]]; do
    echo "No Yubikey inserted"
    echo "Press ctrl+c to exit"
    sleep 1
    serial=$(ykman list --serials | tr '\n' ':' | cut -d ':' -f1)
done
yubikey_slot=1
for (( i=0; i<$yubikey_count; i++))
do
    if [[ "$serial" == "${yubikeys["yubikeys[$i]_serial"]}" ]]; then
        yubikey_slot=${yubikeys["yubikeys[$i]_slot"]}
        break 
    fi
done
echo "Using Yubikey slot: $yubikey_slot"

############################################################################END YUBIKEY SLOT######################################

# Define options
short_options='d:u:n:h'
long_options='device:,uuid:,name:,help:'

# Parse options
args=$(getopt -s bash -o $short_options --long $long_options -- "$@")

# Check for errors
if [ $? != 0 ] ; then echo "Failed to parse options" >&2 ; exit 1 ; fi

eval set -- "$args"

# Process options
while true ; do
    case "$1" in
        -d|--device)
            if [[ "$2" != /dev/* ]]; then
                echo "Not valid device"
                exit 0
            fi
            device="$2"
            shift 2
            ;;
        -u|--uuid)
            uuid="$2"
            shift 2
            ;;
        -n|--name)
            name="$2"
            shift 2
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        --) # End of options
            shift
            break
            ;;
        *) # Invalid option
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

action=$1

if [[ -z "$action" ]]; then
    echo "You need to specify action"
    exit 0
fi
if [[ "$action" != "open" || $drive_count -le 0 ]] || [[ -n $uuid || -n $device ]]; then
    if [[ -z "${uuid+set}" ]]; then
        if [[ -z "${device+set}" ]]; then
            echo "You need to specify device either by -d|--device or -u|--uuid. -u is preferred"
            exit 0
        fi

        uuid=$(blkid "$device" -s UUID -o value)

        # Check if UUID was successfully retrieved
        if [ -z "$uuid" ]; then
            echo "Failed to retrieve UUID for $device"
            exit 0
        fi
    fi
fi

case $action in
    open)
        if [[ $drive_count -gt 0 && -z "${name+set}" && -z "${uuid+set}" ]]; then
            for (( i=0; i<$drive_count; i++))
            do
                uuid=${drives["drives[$i]_uuid"]}
                name=${drives["drives[$i]_name"]}
                #echo "$uuid"
                #echo "$name"
                if [[ ! -e "/dev/disk/by-uuid/$uuid" ]]; then
                    echo "Device with uuid $uuid does not exist"
                    continue
                fi

                should_continue="true"
                while [[ "$should_continue" == "true" ]]; do
                    partlabel=$(blkid /dev/disk/by-uuid/$uuid -s LABEL -o value)
                    echo "Opening device with label: $partlabel and UUID: $uuid"
                    if [ -z "$partlabel" ]; then
                        echo "You can set label with cryptsetup config <device> --label <label>"
                    fi

                    if [[ -z $password ]]; then
                        echo -n "Enter password: "
                        read -s password
                        echo
                    fi
                    echo "Remember to touch your yubikey"


                    state=$(open $uuid $(convert_user_password $password $uuid) $name)

                    if [[ "$state" = "Invalid password" ]]; then
                        echo "$state"
                        unset password
                        should_continue="true"
                    else
                        echo "Opened device $uuid"
                        should_continue="false"
                    fi

                    if [[ ${config["cache_password"]} != "true" ]]; then
                        unset password
                    fi
                done
            done
        else
            if [[ -z "${name+set}" ]]; then
                echo "You need to specify name to map the device to. use -n"
                exit 0
            fi
            if [[ ! -e "/dev/disk/by-uuid/$uuid" ]]; then
                echo "Given device does not exists or is not LUKS container"
                exit 0
            fi
            echo -n "Enter password: "
            read -s password
            echo
            echo "Remember to touch your yubikey"
            open $uuid $(convert_user_password $password $uuid) $name
            unset password
        fi
    ;;
    enroll)
        if [[ ! -e "/dev/disk/by-uuid/$uuid" ]]; then
            echo "Given device does not exists or is not LUKS container"
            exit 0
        fi
        echo -n "Enter LUKS key: "
        read -s interactive_password
        echo
        echo -n "Enter new key: "
        read -s yubikey_password
        echo
        echo -n "Repeat new key: "
        read -s yubikey_password_rpt
        echo
        if ! [ "$yubikey_password" = "$yubikey_password_rpt" ]; then
            unset $yubikey_password
            unset $yubikey_password_rpt
            echo "Passwords do not match."
            exit 0
        fi
        echo "Remember to touch your yubikey"
        enroll_key $uuid $interactive_password $(convert_user_password $yubikey_password $uuid)
        unset yubikey_password
        unset interactive_password
    ;;
    enroll-additional)
        if [[ ! -e "/dev/disk/by-uuid/$uuid" ]]; then
            echo "Given device does not exists or is not LUKS container"
            exit 0
        fi

        echo -n "Enter LUKS key: "
        read -s interactive_password
        echo
        echo -n "Enter new key: "
        read -s yubikey_password
        echo
        echo -n "Repeat new key: "
        read -s yubikey_password_rpt
        echo
        if ! [ "$yubikey_password" = "$yubikey_password_rpt" ]; then
            unset $yubikey_password
            unset $yubikey_password_rpt
            echo "Passwords do not match."
            exit 0
        fi
        echo "Remember to touch your yubikey TWICE"
        enroll_key $uuid $(convert_user_password $interactive_password $uuid) $(convert_user_password $yubikey_password $uuid)
        unset yubikey_password
        unset interactive_password
    ;;
    *)
        echo "Invalid action!"
        echo "Valid actions are: open, enroll, enroll-additional"
    ;;
esac
