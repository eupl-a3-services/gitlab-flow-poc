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

env_deploy() {
    # assert ENV ENV_HOME
    log INFO "Deploying plain .env files to '${ENV_HOME}'"
    mkdir -p "${ENV_HOME}"
    rm -rf "${ENV_HOME:?}/"*
    cp -r dist/* "${ENV_HOME}/"
    ansi-cmd tree ${ENV_HOME}
    #ls -laR "${ENV_HOME}"
}

env_deploy_crypt() {
    log INFO "Encrypting .env files to session-request directory..."
    assert ENV PDS_TOKEN
    find dist/ -type f -name '*.env' | while read -r FILE_PATH; do 
        FILE_NAME=$(basename "${FILE_PATH}")
        FILE_BASE="${FILE_NAME%.*}"
        SESSION_REQUEST_NAME="${FILE_BASE//./-}.env-session-request"
        SESSION_REQUEST_FILE="/cache-volume/session-request/${SESSION_REQUEST_NAME}"

        rm -f "${SESSION_REQUEST_FILE}"

        zip -j -P "${PDS_TOKEN}" "${SESSION_REQUEST_FILE}" "${FILE_PATH}"
    done
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"

if [ "$__CRYPT" = true ]; then
    env_deploy_crypt
else
    env_deploy
fi
