#!/bin/bash

_inspect() {
    log INFO _inspect
    export PS4='\033[1G\033[K\033[0;37m$(date "+%y%m%d-%H%M%S")\033[0m \033[1;33m${BASH_SOURCE[0]}:${LINENO}\033[1;36m:\033[0m '
    set -x
}

setx() {
    local MODE="${1,,}"

    log INFO ${MODE}
    case "${MODE}" in
        inspect)
            _inspect
            ;;
        *)
            log ERROR "setx: unknown mode '$1'" >&2
            return 64
            ;;
    esac
}

setx $1