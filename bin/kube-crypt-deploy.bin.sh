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
                log ERROR "Unexpected extra argument: $1"
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

assert ENV PDS_TOKEN
assert DIR /cache-volume/session-request
assert FILE /cache-volume/session-vault/${AMS_SPACE}.env-session-vault

ctx AHS_ORIGIN
ctx AMS_ORIGIN

export AMS_DEPLOY=$(date '+%y%m%d-%H%M%S')

echo ${DIR_KUBE}
env2dir DIR_KUBE

vars=(
    "AMS_NAME"
    "AMS_PARTITION"
    "AMS_AREA"
    "AMS_DOMAIN"
    "AMS_REVISION"
    "AMS_DEPLOY"
    "AMS_RELEASE"
    "AMS_SPACE"
)

echo > .kube/pipeline.env

for var in "${vars[@]}"; do
    value="${!var}"
    echo "${var}='${value}'" >> .kube/pipeline.env
done

ls -la .kube

for file in .kube/*; do
    [ -f "$file" ] || continue
    ansi-cat "$file"
done

FILE_NAME=$(basename "${FILE_PATH}")
FILE_BASE="${FILE_NAME%.*}"
SESSION_REQUEST_NAME="${AMS_NAME}-${AMS_SPACE}.env-session-request"
SESSION_REQUEST_FILE="/cache-volume/session-request/${SESSION_REQUEST_NAME}"

rm -f "${SESSION_REQUEST_FILE}"

export ANSI_HIGHLIGHT="adding:32"
ansi-cmd zip -j -r -P "${PDS_TOKEN}" "${SESSION_REQUEST_FILE}" ".kube"

for i in {1..50}; do
    if [ ! -f "${SESSION_REQUEST_FILE}" ]; then
    echo "Súbor '${SESSION_REQUEST_FILE}' bol odstránený. Pokračujem."
    exit 0
    fi
    echo "[$i/50] Súbor '${SESSION_REQUEST_FILE}' stále existuje. Čakám 3 sekundy..."
    sleep 3
done

# Ak sa sem dostane, súbor stále existuje – chyba
echo "❌ Súbor '${SESSION_REQUEST_FILE}' stále existuje po 50 pokusoch. Končím s chybou."
exit 1
