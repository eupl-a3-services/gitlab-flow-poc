#!/bin/bash

set -e

log INFO "GLF_LOG: '${GLF_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false
    __CRYPT=false

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
            --crypt) __CRYPT=true ;;
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

yml_to_env(){
    local has_yaml_error=false

    mkdir -p src

    for YML_FILE in src/*.yml; do
        [[ -f "$YML_FILE" ]] || continue

        local BASENAME="${YML_FILE##*/}"
        BASENAME="${BASENAME%.*}"
        local ENV_FILE="src/${BASENAME}.env"

        if [[ -f "$ENV_FILE" ]]; then
            log ERROR "Conversion error: '${YML_FILE}' cannot be converted because '${ENV_FILE}' already exists."
            has_yaml_error=true
            continue
        fi

        log INFO "Converting '${YML_FILE}' → '${ENV_FILE}'"

        for key in $(yq eval 'keys | .[]' "$YML_FILE"); do
            value=$(yq eval ".\"$key\"" "$YML_FILE" -o=json | jq -c .)
            if [[ $value =~ ^\"(.*)\"$ ]]; then
                value="'${BASH_REMATCH[1]}'"
            else
                value="'$value'"
            fi
            echo "${key}=${value}" >> "$ENV_FILE"
        done
    done

    if [[ "$has_yaml_error" == true ]]; then
        log ERROR "Aborting due to YAML conversion errors."
        return 1
    fi
}

env_build() {
    local has_crlf_error=false
    for FILE in src/*.env; do
        if grep -q $'\r' "$FILE"; then
            log ERROR "File '$FILE' contains CRLF line endings (Windows format). Please convert to LF."
            has_crlf_error=true
        fi
    done

    if [[ "$has_crlf_error" == true ]]; then
        log ERROR "Aborting due to CRLF issues."
        return 1
    fi

    mkdir -p dist
    export ENV_REVISION=${AMS_REVISION}
    export ENV_BUILD=${AMS_BUILD}
    ENV_HEAD=$(echo -e "AHS_REVISION=${AHS_REVISION}\nAHS_BUILD=${AHS_BUILD}\nENV_REVISION=${ENV_REVISION}\nENV_BUILD=${ENV_BUILD}\n")
    (
        cd src
        for FILE in *.env; do
            echo "${ENV_HEAD}" > "../dist/${FILE}"
            echo >> "../dist/${FILE}"
            cat "${FILE}" >> "../dist/${FILE}"
        done
    )
}

env_build_crypt() {
    assert ENV PDS_TOKEN
    assert FILE /cache-volume/session-vault/ci-private.key-session-vault
    if ! unzip -p -P "${PDS_TOKEN}" /cache-volume/session-vault/ci-private.key-session-vault > /tmp/private.key; then
        log ERROR "Environment variable 'pds-token' is invalid. Aborting pipeline execution."
        exit 1
    fi

    ansi-cmd gpg --batch --import /tmp/private.key
    ansi-cmd gpg --list-secret-keys

    #git-crypt status
    #cat .gpg.env
    git-crypt unlock

    #git-crypt status
    ansi-cat .gpg.env
    if grep -q "GITCRYPT" .gpg.env; then
        log ERROR "Repo is still locked"
        exit 2
    else
        log INFO "Repo is successfully unlocked"
    fi

    mkdir -p dist
    export ENV_REVISION=${AMS_REVISION}
    export ENV_BUILD=${AMS_BUILD}
    ENV_HEAD=`echo -e "AHS_REVISION=${AHS_REVISION}\nAHS_BUILD=${AHS_BUILD}\nENV_REVISION=${ENV_REVISION}\nENV_BUILD=${ENV_BUILD}\n"`
    (cd src && for FILE in *.env; do echo "${ENV_HEAD}" > ../dist/${FILE} && echo >> ../dist/${FILE} && cat ${FILE} >> ../dist/${FILE}; done)
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"

yml_to_env
if [ "$__CRYPT" = true ]; then
    env_build_crypt
else
    env_build
fi

ctx ENV