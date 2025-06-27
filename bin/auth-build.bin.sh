#!/bin/bash

set -e

log INFO "GLF_LOG: '${GLF_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false

    case "${GLF_LOG}" in
        inspect|INSPECT)
            __INSPECT=true
            __DEBUG=true
            ;;
        debug|DEBUG)
            __DEBUG=true
            ;;
    esac

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --inspect) __INSPECT=true ;;
            --debug) __DEBUG=true ;;
            *) log ERROR "Unknown parameter: $1" ;;
        esac
        shift
    done

    if [ "$__INSPECT" = true ]; then
        . setx INSPECT
    fi

    if [ "$__DEBUG" = true ]; then
        source log level DEBUG
    fi
}

auth_build() {
        output="dist/.auth.htpasswd"
        mkdir -p dist
        > "$output"

        declare -A usernames
        for file in $(find src -maxdepth 1 -name '*.auth.yml' | sort); do
            echo "" >> "$output"
            echo "# 🏢 $file" >> "$output"

            while IFS=$'\t' read -r fullname password; do
                if [[ "$fullname" != *.* ]]; then
                    log ERROR "The user name '$fullname' does not contain a dot."
                    exit 1
                fi

                name_part=$(echo "$fullname" | cut -d '.' -f1)
                surname_part=$(echo "$fullname" | cut -d '.' -f2)

                username="${name_part:0:3}-${surname_part:0:3}"

                if [[ -n "${usernames[$username]}" ]]; then
                    log ERROR "The username '$username' already exists (conflict between '${usernames[$username]}' and '$fullname')."
                    exit 1
                fi

                usernames["$username"]="$fullname"
                echo "## 🧑‍🔬 $fullname" >> "$output"
                htpasswd -nbB "$username" "$password" >> "$output"
            done < <(yq -r '.["qa-auth"][] | [.name, .pass] | @tsv' "$file")

            echo " " >> "$output"
        done
        ansi-cat $output
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"

auth_build
