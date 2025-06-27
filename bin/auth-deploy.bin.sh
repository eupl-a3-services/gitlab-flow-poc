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

auth_deploy() {
    input="dist/.auth.htpasswd"
    cp ${input} ${AUTH_HTPASSWD}
    ansi-cat ${AUTH_HTPASSWD}
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"

auth_deploy
