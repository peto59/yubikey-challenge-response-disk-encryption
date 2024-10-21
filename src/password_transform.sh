password=$1
uuid=$2
echo -n "$password|$uuid" | sha512sum | awk '{print $1}' | ykchalresp -$yubikey_slot -i - | sha512sum | awk '{print $1}'
unset password
