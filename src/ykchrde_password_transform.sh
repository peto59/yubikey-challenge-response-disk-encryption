#!/usr/bin/bash
password=$1
uuid=$2
yubikey_slot=$3
echo "Password transform $yubikey_slot"
echo -n "$password|$uuid" | sha512sum | awk '{print $1}' | /usr/bin/ykchalresp -v -$yubikey_slot | sha512sum | awk '{print $1}'
#echo -n "$password|$uuid" | sha512sum | awk '{print $1}' | ykchalresp -$yubikey_slot -i -
unset password
