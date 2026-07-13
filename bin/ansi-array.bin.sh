#!/bin/bash

ansi_array() {
    local array_name="$1"
    local left_text="$1"
    local -n input_array=$1

    # Check if the passed array is associative
    local assoc=$(declare -p "$array_name" 2>/dev/null)
    local is_associative=false
    if [[ "$assoc" == "declare -A"* ]]; then
        is_associative=true
    fi

    local bar_type="ARRAY-INDEX"
    if [ "$is_associative" = true ]; then
        bar_type="ARRAY-ASSOC"
    fi

    local total_width=120
    local background_color="\033[42;97m"
    local reset_color="\033[0m"

    local -a seen=()
    local -a seen_once=()
    local duplicates=0
    local total=0

    # Get items to process (if associative, extract keys; otherwise, extract values)
    local -a items_to_process=()
    if [ "$is_associative" = true ]; then
        items_to_process=("${!input_array[@]}") # Keys: ams_name
    else
        items_to_process=("${input_array[@]}")   # Standard values
    fi

    for item in "${items_to_process[@]}"; do
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

    ansi-bar "${bar_type}" "${left_text}"

    seen_once=()
    for item in "${items_to_process[@]}"; do
        # Format the output display text based on array type
        local display_text="$item"
        if [ "$is_associative" = true ]; then
            display_text="$item -> ${input_array[$item]}"
        fi

        if [[ ! " ${seen_once[*]} " =~ " ${item} " ]]; then
            seen_once+=("$item")
            printf " \033[1;32m✔ %s\033[0m\n" "$display_text"
        else
            printf " \033[0;33m⚠ Duplicate:\033[0m %s\n" "$display_text"
        fi
    done

    ansi-bar "${bar_type}" "${left_text}" "${right_text}"
}

ansi_array "$@"
