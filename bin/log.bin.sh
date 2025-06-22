#!/bin/bash

: "${GLF_LOG_LEVEL:=INFO}"

log_level() {
    local LEVEL="${1^^}"
    case "${LEVEL}" in
        HEAD|DEBUG|INFO|WARN|ERROR|SUCCESS)
            export GLF_LOG_LEVEL="${LEVEL}"
            echo -e "\033[1;36m[INFO] Log level is set to: ${GLF_LOG_LEVEL}\033[0m"
            ;;
        *)
            echo "Invalid log level '${LEVEL}'. Please use: HEAD, DEBUG, INFO, WARN, ERROR or SUCCESS."
            ;;
    esac
}
log_head() {
    echo -e "\033[1;35m[HEAD] $@\033[0m"
}

log_debug() {
    if [ "${GLF_LOG_LEVEL}" = "DEBUG" ]; then
        echo -e "\033[1;34m[DEBUG] $@\033[0m"
    fi
}

log_info() {
    if [ "${GLF_LOG_LEVEL}" = "INFO" ] || [ "${GLF_LOG_LEVEL}" = "DEBUG" ]; then
        echo -e "\033[1;36m[INFO] $@\033[0m"
    fi
}

log_warn() {
    echo -e "\033[1;33m[WARN] $@\033[0m"
}

log_error() {
    echo -e "\033[1;31m[ERROR] $@\033[0m"
}

log_assert() {
    echo -e "\033[1;41m[ASSERT] $@\033[0m"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS] $@\033[0m"
}

log_usage() {
    echo -e "\033[1;36m[USAGE] $@\033[0m"
}

log_value() {
    local LOG_KEY=$1
    printf -v LOG_KEY "%-25s" "${LOG_KEY}:"
    shift
    local LOG_VALUE=$@ #{!LOG_KEY}
    echo -e "\033[1;34m[VALUE] ${LOG_KEY} '\033[0m${LOG_VALUE}\033[1;34m'\033[0m"
}

GLF_LOG_SCOPE="${1,,}"

case "${GLF_LOG_SCOPE}" in
    level)
        shift
        log_level "$@"
        ;;
    head)
        shift
        log_head "$@"
        ;;
    debug)
        shift
        log_debug "$@"
        ;;
    info)
        shift
        log_info "$@"
        ;;
    warn)
        shift
        log_warn "$@"
        ;;
    error)
        shift
        log_error "$@"
        ;;
    assert)
        shift
        log_assert "$@"
        ;;
    success)
        shift
        log_success "$@"
        ;;
    usage)
        shift
        log_usage "$@"
        ;;
    value)
        shift
        log_value "$@"
        ;;
    *)
        log_info "$@"
        ;;
esac
