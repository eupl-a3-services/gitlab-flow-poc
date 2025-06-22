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
    SRC_DIR="src"
    DIST_DIR="dist"
    KUBECONFIG_DIR="${SRC_DIR}/.kubeconfig"

    rm -rf "${DIST_DIR}"
    mkdir -p "${DIST_DIR}"

    find "${SRC_DIR}" -mindepth 1 -not -path "${SRC_DIR}/.kubeconfig*" | while read -r path; do
        relative_path="${path#${SRC_DIR}/}"
        target_path="${DIST_DIR}/${relative_path}"

        if [ -d "${path}" ]; then
            mkdir -p "${target_path}"
        else
            mkdir -p "$(dirname "${target_path}")"
            cp "${path}" "${target_path}"
        fi
    done

    find "${DIST_DIR}" -type f -name "*.kubeconfig" | while read -r kube_file; do
        if [ ! -s "${kube_file}" ]; then
            filename="$(basename "${kube_file}" .kubeconfig)"
            source_kubeconfig="${KUBECONFIG_DIR}/${filename}.yml"

            if [ -f "${source_kubeconfig}" ]; then
                log INFO "Source kubeconfig for '${kube_file}' using '${source_kubeconfig}'"
                cp "${source_kubeconfig}" "${kube_file}"
            else
                log ERROR "Source kubeconfig for '${kube_file}' using '${source_kubeconfig}' was not found!"
            fi
        fi

        mv "${kube_file}" "${kube_file}.yml"
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
