declare -A config

current_section=""
while IFS= read -r line; do
    if [[ $line =~ ^\[.*\]$ ]]; then
        # Extract section name without brackets
        current_section=${line:1:-1}
    elif [[ ! -z "$line" && ! "$line" =~ ^# && ! "$line" =~ ^=*$ ]]; then
        # Split variable assignment into name and value
        IFS='=' read -r name value <<< "$line"
        name=${name//[[:space:]]/} # Remove spaces around name
        value=${value//[[:space:]]/} # Remove spaces around value
        
        # Append value to existing key or initialize new key
        if [[ -z "${config["$current_section,$name"]}" ]]; then
            config["$current_section,$name"]=$value
        else
            config["$current_section,$name"]="${config["$current_section,$name"]},$value"
        fi
    fi
done < "ykchrde.conf"









printf "%s\n" "${!config[@]}" "${config[@]}" | pr -2t

