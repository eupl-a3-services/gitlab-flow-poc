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

check_pipeline_source() {
  if [ "${CI_PIPELINE_SOURCE}" != "pipeline" ]; then
    log INFO "Skipping further execution. CI_PIPELINE_SOURCE is '${CI_PIPELINE_SOURCE}'."
    log INFO "This pipeline is designed to process pipelines with CI_PIPELINE_SOURCE: 'pipeline'."
    exit 0
  fi
}

ctx AHS_ORIGIN

argument_config "$@"
check_pipeline_source

ctx AMS_ORIGIN
