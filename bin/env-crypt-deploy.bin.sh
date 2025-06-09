#!/bin/bash

set -e

log INFO "AMS_LOG: '${AMS_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false

    case "${AMS_LOG}" in
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
            *)
                log ERROR "Unexpected positional argument: $1"
                ;;
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

env_crypt_deploy() {
    assert ENV PDS_TOKEN
    find dist/ -type f -name '*.env' | while read FILE_PATH; do 
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
env_crypt_deploy
