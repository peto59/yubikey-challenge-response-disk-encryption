parseDriveProperties() {
    local propertiesString="$1"
    local tempIFS=$IFS
    IFS=' '
    read -ra pairs <<< "$propertiesString"
    declare -A driveProps
    for pair in "${pairs[@]}"; do
        IFS='=' read -r key value <<< "$pair"
        driveProps["$key"]=$value
    done
    IFS=$tempIFS
    echo "${driveProps["uuid"]}"
}

declare -a drives
currentDriveIndex=-1
currentSection=""

while IFS= read -r line; do
    if [[ $line =~ ^\[.*\]$ ]]; then
        currentSection=${line:1:-1}
        if [[ $currentSection == "drive" ]]; then
            ((currentDriveIndex++))
            drives[currentDriveIndex]=""
        fi
    elif [[ $currentSection == "drive" && ! -z "$line" && ! "$line" =~ ^# && ! "$line" =~ ^=*$ ]]; then
        # Parse variable assignment into name and value
        IFS='=' read -r name value <<< "$line"
        name=${name//[[:space:]]/} # Remove spaces around name
        value=${value//[[:space:]]/} # Remove spaces around value
        # Append property to current drive
        drives[currentDriveIndex]+="$name=$value "
    fi
done < "ykchrde.conf"

printf "Drives count = ${#drives[@]}\n"
printf "%s\n" "${!drives[@]}" "${drives[@]}" | pr -2t
printf $(parseDriveProperties ${drives[0]})["uuid"]
