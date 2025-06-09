#!/bin/bash

ansi_array() {
    local array_name="$1"
    local left_text="$1"
    local -n input_array=$1

    local total_width=120
    local background_color="\033[42;97m"
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

    local right_text="total: $total | unique: $unique | duplicates: $duplicates"

    ansi-bar ARRAY "${left_text}"

    seen_once=()
    for item in "${input_array[@]}"; do
        if [[ ! " ${seen_once[*]} " =~ " ${item} " ]]; then
            seen_once+=("$item")
            printf " \033[1;32m✔ %s\033[0m\n" "$item"
        else
            printf " \033[0;33m⚠ Duplicate:\033[0m %s\n" "$item"
        fi
    done

    ansi-bar ARRAY "${left_text}" "${right_text}"
}

ansi_array "$@"