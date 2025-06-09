#!/bin/bash

ansi_cat() {
    left_text="$1"

    file_size=$(stat -c %s "$1")
    line_count=$(awk 'END { print NR }' "$1")
    right_text="bytes: $file_size | lines: $line_count"
    
    ansi-bar CAT "${left_text}"
    highlight -O ansi "$1"
    ansi-bar CAT "${left_text}" "${right_text}"
}

ansi_cat "$@"