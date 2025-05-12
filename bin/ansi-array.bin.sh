ansi_array() {
    local -n input_array=$1
    local array_name="$1"

    local total_width=120
    local header_color="\033[42;97m"
    local reset_color="\033[0m"

    local -a seen=()
    local -a seen_once=()
    local duplicates=0
    local total=0

    for item in "${input_array[@]}"; do
        total=$((total + 1))
        if [[ ! " ${seen[*]} " =~ " ${item} " ]]; then
            seen+=("$item")
            seen_once+=("$item")
        else
            duplicates=$((duplicates + 1))
        fi
    done

    local unique=${#seen_once[@]}
    local header_left="Array: \`${array_name}\`"
    local footer_right="Total: $total | Unique: $unique | Duplicates: $duplicates"
    local padding_header=$((total_width - ${#header_left}))
    local padding_footer=$((total_width - 1 - ${#header_left} - ${#footer_right}))

    printf "${header_color} %s%*s${reset_color}\n" "$header_left" "$padding_header" ""

    seen_once=()
    for item in "${input_array[@]}"; do
        if [[ ! " ${seen_once[*]} " =~ " ${item} " ]]; then
            seen_once+=("$item")
            printf " \033[1;32m✔ %s\033[0m\n" "$item"
        else
            printf " \033[0;33m⚠ Duplicate:\033[0m %s\n" "$item"
        fi
    done

    printf "${header_color} %s%*s%s ${reset_color}\n" "$header_left" "$padding_footer" "" "$footer_right"
}

ansi_array "$@"