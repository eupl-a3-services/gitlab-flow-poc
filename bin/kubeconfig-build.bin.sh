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

kubeconfig_build() {
    SRC_DIR=src
    DIST_DIR=dist

    rm -rf "${DIST_DIR:?}"/*
    mkdir -p "${DIST_DIR}"

    yq eval -o=json '.. | select(tag == "!!str") | {"path": path | join("/"), "value": .}' ${SRC_DIR}/kubeconfig.yml | \
    jq -r '"\(.path): \(.value)"' | \
    while IFS= read -r record; do
        dir="${record%%:*}"
        file="${record#*: }"

        if [[ "$dir" == *"/_file" ]]; then
            dir="${dir%/_file}"
        fi

        mkdir -p ${DIST_DIR}/${dir}
        source_path="${SRC_DIR}/.kubeconfig/${file}"

        if [[ ! -f "$source_path" ]]; then
            log ERROR "Unexpected file '${file}' found in directory '${DIST_DIR}/${dir}'. The file name does not match any known configuration."
        else
            echo ${source_path} '>>>' ${DIST_DIR}/${dir}
            cp ${source_path} ${DIST_DIR}/${dir}
        fi
    done

    log INFO SUCCESS "Result is in '${DIST_DIR}' directory"
}

kubeconfig_build_crypt() {
    exit 1
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"

if [ "$__CRYPT" = true ]; then
    kubeconfig_build_crypt
else
    kubeconfig_build
fi
