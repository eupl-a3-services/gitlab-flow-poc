#!/bin/bash

ansi_bar() {
    local label="$1"
    local left_text="$2"
    local right_text="$3"
    local total_width=120
    local background_color
    local reset_color="\033[0m"

    if [ -z "$right_text" ]; then
        right_text="▶▶▶"
        local left_text="${label,,}: '$2'"
    fi

    case "$label" in
        CAT) background_color="\033[44;97m" ;;
        ARRAY) background_color="\033[42;97m" ;;
        LINT-ENV) background_color="\033[46;97m" ;;
        CMD) background_color="\033[45;30m" ;;
        *) background_color="\033[47;30m" ;;
    esac

    local padding=$((total_width - ${#left_text} - ${#right_text} - 2))
    printf "${background_color} %s%*s%s ${reset_color}\n" "$left_text" "$padding" "" "$right_text"
}

ansi_bar "$@"