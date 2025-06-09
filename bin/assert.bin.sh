#!/bin/bash

assert() {
    local TYPE="$1"
    local VALUE="$2"

    case "$TYPE" in
        ENV)
            if [ -z "${!VALUE}" ]; then
                log ASSERT "ENV: Environment variable '$VALUE' is not set!"
                exit 1
            fi
            ;;
        DIR)
            if [ ! -d "$VALUE" ]; then
                log ASSERT "DIR: Directory '$VALUE' does not exist!"
                exit 2
            fi
            ;;
        FILE)
            if [ ! -f "$VALUE" ]; then
                log ASSERT "FILE: File '$VALUE' does not exist!"
                exit 3
            fi
            ;;
        GLOB)
            local FILES=( $VALUE )
            if [ ${#FILES[@]} -eq 0 ] || [ ! -e "${FILES[0]}" ]; then
                log ASSERT "GLOB: No file matches pattern '${VALUE//\\}'!"
                exit 4
            fi
            ;;
        *)
            log ERROR "Unknown assert type: '$TYPE'. Use {ENV|DIR|FILE|GLOB}."
            exit 64
            ;;
    esac
}

if [[ $# -ne 2 ]]; then
    log USAGE "$0 {ENV|DIR|FILE|GLOB} VALUE"
    exit 64
fi

assert "$1" "$2"