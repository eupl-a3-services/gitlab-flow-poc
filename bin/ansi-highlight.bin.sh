#!/bin/bash

ansi_highlight() {
    local patterns_str="${ANSI_HIGHLIGHT:-}"

    IFS=',' read -r -a patterns <<< "$patterns_str"

    local -a sed_script=()
    local esc=$'\033'

    for p in "${patterns[@]}"; do
        [[ -z "$p" ]] && continue
        local word="${p%%:*}"
        local color_code="${p#*:}"

        local color="${esc}[${color_code}m"
        local reset="${esc}[0m"

        local sed_expr="s/${word}/${color}&${reset}/g"

        sed_script+=("-e" "$sed_expr")
    done

    if (( ${#sed_script[@]} )); then
        sed "${sed_script[@]}"
    else
        cat
    fi
}

ansi_highlight
