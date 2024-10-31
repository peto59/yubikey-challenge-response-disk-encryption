#!/usr/bin/bash
password=$1
uuid=$2
yubikey_slot=$(echo $3 | xargs)
echo -n "$password|$uuid" | sha512sum | awk '{print $1}' | /usr/bin/ykchalresp -1 -i - | sha512sum | awk '{print $1}'
unset password
