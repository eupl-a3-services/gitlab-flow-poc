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

kubeconfig_deploy() {
    # assert ENV KUBECONFIG_HOME
    log INFO "Deploying plain '.kubeconfig.yml' files to '${KUBECONFIG_HOME}"
    mkdir -p "${KUBECONFIG_HOME}"
    rm -rf "${KUBECONFIG_HOME:?}/"*
    cp -r dist/* "${KUBECONFIG_HOME}/"
    ansi-cmd tree ${KUBECONFIG_HOME}
    #ls -laR "${KUBECONFIG_HOME}"
}

kubeconfig_deploy_crypt() {
    exit 1
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"

if [ "$__CRYPT" = true ]; then
    kubeconfig_deploy_crypt
else
    kubeconfig_deploy
fi
