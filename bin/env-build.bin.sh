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
        PS4='\033[1G\033[K\033[1;36m$(date "+%y%m%d-%H%M%S")\033[0m \033[1;33m${BASH_SOURCE[0]}:${LINENO}\033[1;36m:\033[0m '
        set -x
    fi

    if [ "$__DEBUG" = true ]; then
        source log level DEBUG
    fi
}

env_build() {
    mkdir -p dist
    export ENV_REVISION=${AMS_REVISION}
    export ENV_BUILD=${AMS_BUILD}
    ENV_HEAD=`echo -e "AHS_REVISION=${AHS_REVISION}\nAHS_BUILD=${AHS_BUILD}\nENV_REVISION=${ENV_REVISION}\nENV_BUILD=${ENV_BUILD}\n"`
    (cd src && for FILE in *; do echo "${ENV_HEAD}" > ../dist/${FILE} && echo >> ../dist/${FILE} && cat ${FILE} >> ../dist/${FILE}; done)
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"
env_build

ctx ENV
