#!/bin/bash

_required() {
    REQ_WIDTH=$1
    REQ_KEY_WIDTH=$2
    local REQ_TITLE=$3
    local ANSI_PURPLE="\033[1;35m"
    local ANSI_NC="\033[0m"

    printf "+[${ANSI_PURPLE}%s${ANSI_NC}]%*s+\n" "${REQ_TITLE}" $((REQ_WIDTH - ${#REQ_TITLE} - 2)) "" | tr ' ' '-'
}

_req() {
    local REQ_KEY=$1
    local ANSI_PURPLE="\033[1;35m"
    local ANSI_RED="\033[1;31m"
    local ANSI_NC="\033[0m"

    if [[ -z "$REQ_KEY" ]]; then
        printf "+%$((REQ_WIDTH - 3))s${ANSI_PURPLE}🄰🄼🅂${ANSI_NC}+\n" | tr ' ' '-'
    else
        local REQ_VALUE=${!REQ_KEY}
        if [[ -z "$REQ_VALUE" ]]; then
            printf "|${ANSI_RED} %-*s %-*s ${ANSI_NC}|\n" "${REQ_KEY_WIDTH}" "${REQ_KEY}:" $((REQ_WIDTH - REQ_KEY_WIDTH - 3)) "(empty)"
        else
            printf "| %-*s %-*s |\n" "${REQ_KEY_WIDTH}" "${REQ_KEY}:" $((REQ_WIDTH - REQ_KEY_WIDTH - 3)) "${REQ_VALUE}"
        fi
    fi
}

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 PARAM1 PARAM2 ..."
    exit 1
fi

_required 80 20 REQ
for param in "$@"; do
    _req "$param"
done
_req
