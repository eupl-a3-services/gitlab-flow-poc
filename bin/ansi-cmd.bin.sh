#!/bin/bash

ansi_cmd() {
    local left_text="$*"
    local cmd="$*"
    local start_time=$(date +%s.%N)

    ansi-bar CMD "${left_text}"

    local output
    output=$(eval "$cmd" 2>&1)
    local exit_code=$?

    local end_time=$(date +%s.%N)
    local duration=$(awk "BEGIN { printf \"%.2fs\", ${end_time} - ${start_time} }")

    echo "$output" | ansi-highlight

    local right_text="exit: $exit_code | duration: $duration"
    ansi-bar CMD "${left_text}" "${right_text}"

    return $exit_code
}

ansi_cmd "$@"
exit $?
