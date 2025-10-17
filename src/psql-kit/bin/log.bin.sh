#!/bin/bash
#SCRIPT_NAME=/usr/local/bin/log; cat <<"EOS" > ${SCRIPT_NAME}

: "${AMS_LOG_LEVEL:=INFO}"

do_log() {
    local scope="$1"
    shift
    local message="$@"
    local timestamp=$(date "+%y%m%d-%H%M%S")
    local formatted_message="${timestamp} [${scope^^}] ${message}"
    local ansi_color=""

    case "${scope^^}" in
        HEAD) ansi_color="\033[1;35m" ;;
        DEBUG) ansi_color="\033[1;34m" ;;
        INFO) ansi_color="\033[1;36m" ;;
        WARN) ansi_color="\033[1;33m" ;;
        ERROR) ansi_color="\033[1;31m" ;;
        SUCCESS) ansi_color="\033[1;32m" ;;
        *) ansi_color="" ;;
    esac

    echo -e "${ansi_color}${message}\033[0m"

    if [ -n "$AMS_LOG_DIR" ]; then
        local log_file="${AMS_LOG_DIR}/${AMS_NAME}-$(date '+%yw%U').log"
        mkdir -p "$(dirname "$log_file")"
        echo -e "${ansi_color}${formatted_message}\033[0m" >> "$log_file"
    fi
}

log_level() {
    local LEVEL="${1^^}"
    case "${LEVEL}" in
        HEAD|DEBUG|INFO|WARN|ERROR|SUCCESS)
            export AMS_LOG_LEVEL="${LEVEL}"
            do_log INFO "Log level is set to: ${AMS_LOG_LEVEL}"
            ;;
        *)
            do_log ERROR "Invalid log level '${LEVEL}'. Please use: HEAD, DEBUG, INFO, WARN, ERROR or SUCCESS."
            ;;
    esac
}

log_head() {
    do_log HEAD "$@"
}

log_debug() {
    if [ "${AMS_LOG_LEVEL}" = "DEBUG" ]; then
        do_log DEBUG "$@"
    fi
}

log_info() {
    if [ "${AMS_LOG_LEVEL}" = "INFO" ] || [ "${AMS_LOG_LEVEL}" = "DEBUG" ]; then
        do_log INFO "$@"
    fi
}

log_warn() {
    do_log WARN "$@"
}

log_error() {
    do_log ERROR "$@"
}

log_success() {
    do_log SUCCESS "$@"
}

AMS_LOG_SCOPE="${1,,}"

case "${AMS_LOG_SCOPE}" in
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
    success)
        shift
        log_success "$@"
        ;;
    *)
        log_info "$@"
        ;;
esac

exit 0
EOS
chmod 755 ${SCRIPT_NAME}