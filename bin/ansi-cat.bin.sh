ansi_cat() {
    file_size=$(stat -c %s "$1")
    line_count=$(wc -l < "$1")
    
    file_name="File: '$1'"
    footer_info="Bytes: $file_size | Lines: $line_count"
    
    total_width=120
    padding=$((total_width - ${#file_name} - ${#footer_info} - 2))

    background_color="\033[44;97m"
    reset_color="\033[0m"

    printf "${background_color}%-$((total_width + 1))s${reset_color}\n" " $file_name $(printf '%*s' $((padding + 10)))"
    highlight -O ansi "$1"
    printf "${background_color}%-${total_width}s${reset_color}\n" " $file_name $(printf '%*s' $padding '')$footer_info "
}

ansi_cat "$@"