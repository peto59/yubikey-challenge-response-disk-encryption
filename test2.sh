
declare -a drives
declare -A driveProps
currentSection=""

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

printf "%s\n" "${!config[@]}" "${config[@]}" | pr -2t

