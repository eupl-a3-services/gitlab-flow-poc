#!/bin/bash

set -e

log INFO "GLF_LOG: '${GLF_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false
    __QA=false
    __TLS=false

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
            --qa) __QA=true ;;
            --tls) __TLS=true ;;
            *) log ERROR "Unknown parameter: $1"; exit 64 ;;
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

qa_auth() {
    if [[ "$__QA" == "true" ]]; then
        log INFO QA_AUTH: enable 
        output="dist/.auth.htpasswd"
        mkdir -p dist
        > "$output"

        declare -A usernames
        for file in $(find src -maxdepth 1 -name '*.qa-auth.yml' | sort); do
            #echo "" >> "$output"
            line="# 🏢 $file "
            printf "%-70s\n" "$line" | sed 's/ /#/g' >> "$output"
            #echo "# 🏢 $file" >> "$output"

            while IFS=$'\t' read -r fullname login_file password; do
                if [[ "$fullname" != *.* ]]; then
                    log ERROR "The user name '$fullname' does not contain a dot."
                    exit 1
                fi

                name_part=$(echo "$fullname" | cut -d '.' -f1)
                surname_part=$(echo "$fullname" | cut -d '.' -f2)

                login_calc="${name_part:0:3}-${surname_part:0:3}"

                if [[ "$login_calc" != "$login_file" ]]; then
                    log ERROR "Login mismatch for '$fullname': calculated '$login_calc' but file specifies '$login_file'."
                    exit 2
                fi

                if [[ -n "${usernames[$login_calc]}" ]]; then
                    log ERROR "The username '$login_calc' already exists (conflict between '${usernames[$login_calc]}' and '$fullname')."
                    exit 3
                fi

                usernames["$login_calc"]="$fullname"
                echo "## 🧑‍🔬 $fullname" >> "$output"
                htpasswd -nbB "$login_calc" "$password" >> "$output"
            done < <(yq -r '.["qa-auth"][] | [.name, .login, .pass] | @tsv' "$file")

            #echo " " >> "$output"
        done

        ansi-cat "$output"
        export QA_AUTH_BASE64=$(base64 -w0 "$output")
    fi
}
tls_auth() {
    if [[ "$__TLS" == "true" ]]; then
        log INFO TLS_AUTH: enable
        assert ENV TLS_CRT
        assert ENV TLS_KEY
        export TLS_CRT_BASE64=$(cat "${TLS_CRT}" | base64 -w0)
        export TLS_KEY_BASE64=$(cat "${TLS_KEY}" | base64 -w0)
    fi
}

kube_secret_env() {
    SECRET_BUILD_ENV=kube-secret.env
    cat << EOF > "${SECRET_BUILD_ENV}"
QA_AUTH_BASE64=${QA_AUTH_BASE64}
TLS_CRT_BASE64=${TLS_CRT_BASE64}
TLS_KEY_BASE64=${TLS_KEY_BASE64}
EOF
    log INFO "Secret file '${SECRET_BUILD_ENV}' was successfully created."
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"

qa_auth
tls_auth
kube_secret_env
