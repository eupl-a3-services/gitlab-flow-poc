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
        FILE)
            if [ ! -f "$VALUE" ]; then
                log ASSERT "FILE: File '$VALUE' does not exist!"
                exit 1
            fi
            ;;
        GLOB)
            local FILES=( $VALUE )
            if [ ${#FILES[@]} -eq 0 ] || [ ! -e "${FILES[0]}" ]; then
                log ASSERT "GLOB: No file matches pattern '${VALUE//\\}'!"
                exit 1
            fi
            ;;
        *)
            log ERROR "Unknown assert type: '$TYPE'. Use 'ENV', 'FILE', or 'GLOB'."
            exit 64
            ;;
    esac
}

# Usage check
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 {ENV|FILE|GLOB} VALUE"
    exit 64
fi

assert "$1" "$2"