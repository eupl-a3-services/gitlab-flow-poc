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

glf_lint() {
    GLF_SEMVER=$(cat "$GLF_VERSION" 2>/dev/null || echo "0.0.0")

    IMAGE=$(yq '.image' .gitlab-ci.yml)
    CURRENT_VERSION="${IMAGE#*:}"
    CURRENT_SEMVER="${CURRENT_VERSION%%-*}"

    log INFO "Current GLF semver: $CURRENT_SEMVER"
    log INFO "Last known GLF semver: $GLF_SEMVER"

    if [[ "$CURRENT_SEMVER" == "$GLF_SEMVER" ]]; then
    log SUCCESS "GLF semver is up to date."
    exit 0
    fi

    LATEST_SEMVER=$(printf "%s\n%s\n" "$CURRENT_SEMVER" "$GLF_SEMVER" | sort -V | tail -n1)

    if [[ "$LATEST_SEMVER" == "$GLF_SEMVER" ]]; then
    log ERROR "Newer GLF semver is available: $GLF_SEMVER"
    exit 1
    else
    log INFO "Updating GLF semver tracked version to $CURRENT_SEMVER"
    echo "$CURRENT_SEMVER" > "$GLF_VERSION"
    exit 0
    fi
}

ctx AHS_ORIGIN

argument_config "$@"

glf_lint

ctx ENV