#!/bin/bash

assert() {
    local TYPE="$1"
    local VALUE="$2"
    local DEFAULT="$3"

    case "$TYPE" in
        ENV)
            if [ -z "${!VALUE}" ]; then
                if [ -n "$DEFAULT" ]; then
                    export "$VALUE=$DEFAULT"
                    log ASSERT "ENV: '$VALUE' not set, using default '$DEFAULT'"
                else
                    log ASSERT "ENV: Environment variable '$VALUE' is not set!"
                    exit 1
                fi
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

if [[ $# -lt 2 || $# -gt 3 ]]; then
    log USAGE "$0 {ENV|DIR|FILE|GLOB} VALUE [DEFAULT]"
    exit 64
fi

assert "$1" "$2" "$3"