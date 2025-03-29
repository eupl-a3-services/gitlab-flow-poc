#!/bin/bash

ams_hub_ctx() {
    _context 80 20 AMS-HUB-CTX
    _ctx AMS_HUB_NAME ${AMS_HUB_NAME}
    _ctx AMS_HUB_REVISION ${AMS_HUB_REVISION}
    _ctx AMS_HUB_BUILD ${AMS_HUB_BUILD}
    _ctx
}

ams_origin_ctx() {
    _context 80 20 AMS-ORIGIN-CTX
    _ctx AMS_NAME ${AMS_NAME}
    _ctx AMS_REVISION ${AMS_REVISION}
    _ctx AMS_DIST ${AMS_DIST}
    _ctx AMS_BUILD ${AMS_BUILD}
    _ctx AMS_ZONE ${AMS_ZONE}
    _ctx AMS_RELEASE ${AMS_RELEASE}
    _ctx AMS_BUSINESS ${AMS_BUSINESS}
    _ctx AMS_ROLLOUT ${AMS_ROLLOUT}
    _ctx AMS_TRIGGER ${AMS_TRIGGER}
    _ctx AMS_RESOURCE ${AMS_RESOURCE}
    _ctx
}

ams_container_ctx() {
    _context 80 20 AMS-CONTAINER-CTX
    _ctx AMS_NAME ${AMS_NAME}
    _ctx AMS_REVISION ${AMS_REVISION}
    _ctx AMS_DIST ${AMS_DIST}
    _ctx AMS_BUILD ${AMS_BUILD}
    _ctx AMS_DEPLOY ${AMS_DEPLOY}
    _ctx AMS_ENV ${AMS_ENV}
    _ctx AMS_RELEASE ${AMS_RELEASE}
    _ctx
    _ctx AMS ${AMS}
    _ctx
}

ams_image_ctx() {
    _context 100 20 AMS-IMAGE-CTX
    _ctx AMS_IMAGE_REGISTRY ${AMS_IMAGE_REGISTRY}
    _ctx AMS_IMAGE_LAYERS ${AMS_IMAGE_LAYERS}
    _ctx AMS_IMAGE_SIZE ${AMS_IMAGE_SIZE}
    _ctx
}

ams_ping_ctx() {
    _context 80 20 AMS-PING-CTX
    _ctx AMS_NAMES ${AMS_NAMES_STR}
    _ctx AMS_NAME ${AMS_NAME}
    _ctx AMS_REVISION ${AMS_REVISION}
    _ctx AMS_DEPLOY ${AMS_DEPLOY}
    _ctx AMS_ENV ${AMS_ENV}
    _ctx AMS_AREA ${AMS_AREA}
    _ctx AMS_DOMAIN ${AMS_DOMAIN}
    _ctx AMS_HOST ${AMS_HOST}
    _ctx AMS_ENDPOINT ${AMS_ENDPOINT}
    _ctx
}

_context() {
    CTX_WIDTH=$1
    CTX_KEY_WIDTH=$2
    local CTX_TITLE=$3
    local ANSI_PURPLE="\033[1;35m"
    local ANSI_NC="\033[0m"

    printf "+[${ANSI_PURPLE}%s${ANSI_NC}]%*s+\n" "${CTX_TITLE}" $((CTX_WIDTH - ${#CTX_TITLE} - 2)) "" | tr ' ' '-'
}

_ctx() {
    local CTX_KEY=$1
    shift
    local CTX_VALUE="$*"
    local ANSI_PURPLE="\033[1;35m"
    local ANSI_NC="\033[0m"

    if [[ -z "$CTX_KEY" && -z "$CTX_VALUE" ]]; then
        printf "+%$((CTX_WIDTH - 3))s${ANSI_PURPLE}🄰🄼🅂${ANSI_NC}+\n" | tr ' ' '-'
    else
        printf "| %-*s %-*s |\n" "${CTX_KEY_WIDTH}" "${CTX_KEY}:" $((CTX_WIDTH - CTX_KEY_WIDTH - 3)) "${CTX_VALUE}"
    fi
}

if [[ $# -eq 0 ]]; then
    log INFO "Usage: $0 {AMS_HUB|AMS_ORIGIN|AMS_IMAGE|AMS_CONTAINER|AMS_PING}"
    exit 1
fi

case "$1" in
    AMS_HUB)
        ams_hub_ctx
        ;;
    AMS_ORIGIN)
        ams_origin_ctx
        ;;
    AMS_IMAGE)
        ams_image_ctx
        ;;
    AMS_CONTAINER)
        ams_container_ctx
        ;;
    AMS_PING)
        ams_ping_ctx
        ;;
    *)
        log ERROR "Invalid option: $1"
        log INFO "Usage: $0 {AMS_HUB|AMS_ORIGIN|AMS_IMAGE|AMS_CONTAINER|AMS_PING}"
        exit 2
        ;;
esac
