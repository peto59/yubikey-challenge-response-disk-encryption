#!/usr/bin/bash

function print_help() {
    echo "usage: ykchrde ACTION OPTIONS"
    echo
    echo "ACTIONS:"
    echo "open - opens device, if used without parameters it will try to open all devices from ykchrde.conf"
    echo "enroll - enrolls new yubikey key to device"
    echo "enroll-additional - enrolls new yubikey key to device but uses yubikey to get old password. Use this to enroll another yubikey after you've killed interactive key slot"
    echo "enroll-interactive - enrolls new interactive (non-yubikey) key to the device. Not recommended to use outside of emergencies."
    echo "delete - deletes given yubikey key."
    echo "reencrypt - reencrypts given device"
    echo
    echo "OPTIONS:"
    echo "-d|--device - specifies device on which to take action. Format: /dev/<device>. Ignored if -u|--uuid is set."
    echo "-u|--uuid - specifies device on which to take action through UUID of partition or disk"
    echo "-n|--name - maps device to this name (/dev/mapper/<name>). Ignored if action is enroll."
    echo "-s|--silent - uses output redirection instead of expect when opening containers. Used during boot"
    echo "-h|--help - prints this menu"
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
    local params=$4
    state=$(expect <(
    cat <<EXPECTSCRIPT
    log_user 0
    set timeout -1
    spawn cryptsetup $params open /dev/disk/by-uuid/$uuid $mapping
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

function open_silent() {
    local uuid=$1
    local password=$2
    local mapping=$3
    local params=$4

    if ! echo $password | cryptsetup $params open /dev/disk/by-uuid/$uuid $mapping; then
        echo "Invalid password"
    else
        echo "Device opened"
    fi
}
########################################################MAIN LOGIC####################################################
# Define options
short_options='d:u:n:hs'
long_options='device:,uuid:,name:,help,silent'

# Parse options
args=$(getopt -s bash -o $short_options --long $long_options -- "$@")

# Check for errors
if [ $? != 0 ] ; then echo "Failed to parse options" >&2 ; exit 1 ; fi

eval set -- "$args"

silent=false

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
        -s|--silent)
            silent=true
            shift 1
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
    echo "You need to specify action, use -h to show help"
    exit 0
fi
#################################################CONFIG READ##############################################################
if [[ "$action" != "reencrypt" ]]; then
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
    done < "/etc/ykchrde.conf"

    drive_count=$drive_index
    yubikey_count=$yubikey_index

fi

# echo "Config:"
# for key in "${!config[@]}"; do
#     echo "$key=${config[$key]}"
# done
#
# echo "Drives:"
# for i in "${!drives[@]}"; do
#     # Extract drive index and key from the composite key
#     IFS='_' read -r drive_index key <<< "$i"
#     echo "Drive $drive_index:"
#     echo "  $key=${drives[$i]}"
# done

#To access value you use ${drives["drives[$index]_$key"]}
#To access value you use ${yubikeys["yubikeys[$index]_$key"]}
###################################################################GET UUID############################################################
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
##########################################################################YUBIKEY SLOT############################################
if [[ "$action" != "reencrypt" ]]; then
    serial=$(ykinfo -s | tr -d 'serial: ')
    while [[ -z $serial ]]; do
        echo "No Yubikey inserted"
        echo "Press ctrl+c to exit"
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
fi
echo "Using Yubikey slot: $yubikey_slot"
############################################################################ACTIONS###############################################

case $action in
    open)
        # automatic open of all drives in ykchrde.conf
        if [[ $drive_count -gt 0 && -z "${name+set}" && -z "${uuid+set}" ]]; then
            for (( i=0; i<$drive_count; i++))
            do
                uuid=${drives["drives[$i]_uuid"]}
                name=${drives["drives[$i]_name"]}
                trim=${drives["drives[$i]_trim"]}
                params=${drives["drives[$i]_params"]}

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

                    if [[ "$trim" == "1" ]]; then
                        params="$params --allow-discards"
                    fi

                    if [[ $silent ]]; then
                      state=$(open_silent $uuid $(./ykchrde_password_transform.sh $password $uuid $yubikey_slot) $name $params)
                    else
                        state=$(open $uuid $(./ykchrde_password_transform.sh $password $uuid $yubikey_slot) $name $params)
                    fi

                    if [[ "$state" == "Invalid password" ]]; then
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
        # manual open of single drive
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
            open $uuid $(./ykchrde_password_transform.sh $password $uuid $yubikey_slot) $name
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
        enroll_key $uuid $interactive_password $(./ykchrde_password_transform.sh $yubikey_password $uuid $yubikey_slot)
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
        enroll_key $uuid $(./ykchrde_password_transform.sh $interactive_password $uuid $yubikey_slot) $(./ykchrde_password_transform.sh $yubikey_password $uuid $yubikey_slot)
        unset yubikey_password
        unset interactive_password
    ;;
    enroll-interactive)
        if [[ ! -e "/dev/disk/by-uuid/$uuid" ]]; then
            echo "Given device does not exists or is not LUKS container"
            exit 0
        fi
        echo "ATTENTION: This enrolls new INTERACTIVE (NON-YUBIKEY) key to this drive."
        echo "If this is not your intention press ctrl+c to exit."

        echo -n "Enter LUKS key: "
        read -s yubikey_password
        echo
        echo -n "Enter new key: "
        read -s interactive_password
        echo
        echo -n "Repeat new key: "
        read -s interactive_password_rpt
        echo
        if ! [ "$interactive_password" = "$interactive_password_rpt" ]; then
            unset $interactive_password
            unset $interactive_password_rpt
            echo "Passwords do not match."
            exit 0
        fi
        echo "Remember to touch your yubikey TWICE"
        enroll_key $uuid $(./ykchrde_password_transform.sh $yubikey_password $uuid $yubikey_slot) $interactive_password
        unset yubikey_password
        unset interactive_password
    ;;
    delete)
      echo "not yet implemented"
    ;;
    reencrypt)
        if [[ ! -e "/dev/disk/by-uuid/$uuid" ]]; then
            echo "Given device does not exists or is not LUKS container"
            exit 0
        fi
        expect <(
            cat <<EXPECTSCRIPT
            log_user 1
            set timeout -1
            set loop 1
            spawn cryptsetup $params reencrypt /dev/disk/by-uuid/$uuid
            set main_pid \$spawn_id
            set user_password ""
            set yubikey_password ""
            set key_slot_number 0
            while {\$loop == 1} {
                expect {
                    -re {^\s*Enter passphrase for key slot (\d{1,2}):\s*$} {
                        #upvar key_slot_number key_slot_number

                        send_user "Gucci\n"

                        set key_slot_number_local \$expect_out(1,string)
                        #puts "The key slot number is: \$key_slot_number_local"
                        #puts "Last key slot number was: \$key_slot_number"
                        if {\$key_slot_number_local != \$key_slot_number} {
                            set key_slot_number \$key_slot_number_local
                            set user_password ""
                            set yubikey_password ""
                        }

                        if {\$user_password == ""} {
                            spawn systemd-ask-password -n --no-tty --echo=no --timeout=0 --id="cryptsetup-reencrypt:$device:\$key_slot_number_local" "cryptsetup reencrypt $device keyslot: \$key_slot_number_local: "
                            set ask_password_pid \$spawn_id
                            expect {
                                eof {
                                    #upvar user_password user_password
                                    set user_password \$expect_out(buffer)
                                }
                            }

                            set yubikey_slot 1

                            spawn ./ykchrde_get_yubikey_serial.sh
                            set yubikey_serial_pid \$spawn_id
                            expect {
                                eof {
                                    #upvar yubikey_slot yubikey_slot
                                    set yubikey_slot \$expect_out(buffer)
                                }
                            }
                            puts "Spawning password transform with slot \$yubikey_slot"
                            spawn ./ykchrde_password_transform.sh \$user_password $uuid \$yubikey_slot
                            set password_transform_pid \$spawn_id
                            expect {
                                eof {
                                    #upvar yubikey_password yubikey_password
                                    set yubikey_password \$expect_out(buffer)
                                }
                            }
                        }

                        set spawn_id \$main_pid

                        if {\$yubikey_password != ""} {
                            puts "Sending: \$yubikey_password\n"
                            send "\$yubikey_password\n"
                        } elseif {\$user_password != ""} {
                            puts "Sending: \$user_password\n"
                            send "\$user_password\n"
                        }
                    }
                    -re {\s*No key available with this passphrase.\s*} {
                        #upvar user_password user_password
                        #upvar yubikey_password yubikey_password
                        if {\$yubikey_password != ""} {
                            set yubikey_password ""
                        } elseif {\$user_password != ""} {
                            set user_password ""
                        }
                        send_user "Wrong password\n"
                    }
                    -re {.*Finished, time.*} {
                        send_user "Reencryption finished successfully\n"
                        exit 0
                    }
                    timeout {
                        send_user "Timed out"
                        set loop 0
                        exit 1
                    }
                    default {
                        send_user "Insufficient priviledge to run cryptsetup, try with sudo\n"
                        set loop 0
                        exit 1
                    }
                }
            }
EXPECTSCRIPT
        )
    ;;
    *)
        echo "Invalid action!"
        echo "Valid actions are: open, enroll, enroll-additional, enroll-interactive, delete or reencrypt"
        exit 1
    ;;
esac
