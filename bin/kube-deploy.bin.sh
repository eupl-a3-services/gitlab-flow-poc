#!/bin/bash

set -e

log INFO "AMS_LOG: '${AMS_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false
    __NOPING=false
    __DELETE=false

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
            --delete) __DELETE=true ;;
            --noping) __NOPING=true ;;
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

setup_env() {
    export AMS_ENV=${CI_ENVIRONMENT_NAME}
    if [[ -z ${AMS_ZONE} || ${AMS_ZONE} == no* ]]; then
        log ERROR "The value \"${AMS_ZONE}\" of AMS_ZONE is invalid. Please provide a valid zone."
        exit 1
    fi
    export AMS_ENV="${AMS_ENV}-${AMS_ZONE}"
    
    if [[ ! -f "${ENV_HOME}/${AMS_ENV}.env" ]]; then
        log ERROR "Configuration file \"${ENV_HOME}/${AMS_ENV}.env\"not found. The environment \"${AMS_ENV}\" is not properly configured."
        exit 2
    fi
    log INFO ${ENV_HOME}/${AMS_ENV}.env
    if [ "$__DEBUG" = true ]; then
        ansi-cat ${ENV_HOME}/${AMS_ENV}.env
    fi
    set -o allexport
    source ${ENV_HOME}/${AMS_ENV}.env
    
    export AMS_DEPLOY=$(date '+%y%m%d-%H%M%S')
    export AMS_AREA=${AMS_AREA:-$AMS_ENV}
    if [[ -n "$AMS_AREA" ]]; then
        export AMS_AREA="-${AMS_AREA}"
    fi

    export KUBE_COMPOSE_NAME=kube-compose
    export KUBE_COMPOSE_EXT=yml
}

process_kube_compose() {
    PROCESSED=-processed
    AMS_NAMES_LOCAL=()

    export request_uri='$request_uri'       # used for snippet redirect in ingress
    export hostname='${HOSTNAME}'           # used for stateless pod name
    
    DIR=$(pwd)

    > ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}

    for file in $DIR/'$'${KUBE_COMPOSE_NAME}*.${KUBE_COMPOSE_EXT}; do
        while IFS= read -r line; do
            if [[ "$line" == !* ]]; then
                COMMAND="$(echo "${line:2}" | tr -d '\n' | tr -d '\r' | xargs)"
                eval "$COMMAND"

                if [[ -n "$AMS_NAME" ]]; then
                    AMS_NAMES_LOCAL+=("$AMS_NAME")
                fi
            fi
        done < <(grep '^!' "$file")

        sed 's/^!/#  EVAL:/' "$file" | envsubst > "${file%.yml}${PROCESSED}.${KUBE_COMPOSE_EXT}"
    done

    for processed_file in $(ls $DIR/*${PROCESSED}.${KUBE_COMPOSE_EXT} | sort); do
        echo "---" >> ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}
        original_file_name=$(basename "$processed_file" | sed "s/${PROCESSED}//")
        echo "## FILE: $original_file_name" >> ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}
        cat "$processed_file" >> ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}
        echo "" >> ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}
    done

    rm -f $DIR/*${PROCESSED}.${KUBE_COMPOSE_EXT}
    ansi-cat ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}

    if [[ -z "${AMS_NAMES[*]}" ]]; then
        AMS_NAMES=("${AMS_NAMES_LOCAL[@]}")
    fi
}

highlight_output() {
    echo "$1" | sed \
        -e $'s/created/\033[32m&\033[0m/g' \
        -e $'s/configured/\033[32m&\033[0m/g' \
        -e $'s/restarted/\033[32m&\033[0m/g' \
        -e $'s/unchanged/\033[33m&\033[0m/g' \
        -e $'s/invalid/\033[31m&\033[0m/g'
}

kube_deploy() {
    KUBE_CURRENT_CONTEXT=$(kubectl config current-context)

    if [ "$__DELETE" = true ]; then
        log INFO "Deleting Kubernetes resources in context '$KUBE_CURRENT_CONTEXT' using kubectl delete"
        kubectl delete --ignore-not-found -f ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT} 2>&1 | \
        sed \
            -e $'s/deleted/\033[32m&\033[0m/g'
    fi

    log INFO "Applying Kubernetes resources in context '$KUBE_CURRENT_CONTEXT' using kubectl apply"
#    kubectl apply -f ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT} 2>&1 | \
#    sed \
#        -e $'s/created/\033[32m&\033[0m/g' \
#        -e $'s/invalid/\033[31m&\033[0m/g'

    output=$(kubectl apply -f ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT} 2>&1)

    highlight_output "$output"

    for deployment in $(echo "$output" | grep "deployment.apps" | awk '{print $1}' | cut -d '/' -f 2); do
        log INFO "DEPLOYMENT: $deployment"
        if echo "$output" | grep -q "deployment.apps/$deployment.*changed"; then
            log INFO "Rollout restart for $deployment"
            highlight_output "$(kubectl rollout restart deployment $deployment -n env-${AMS_ENV})"
        else
            log INFO "No change for $deployment, skipping rollout"
        fi
    done

}

ams_ping() {
    if [ "$__NOPING" = false ]; then
        for name in "${AMS_NAMES[@]}"; do
            export AMS_NAME="$name"  # Nastavenie hodnoty AMS_NAME
            log INFO "Pinging AMS_NAME=$AMS_NAME"
            export AMS_NAMES_STR=${AMS_NAMES[*]}
            export AMS_HOST="${AMS_NAME}${AMS_AREA}.${AMS_DOMAIN}"
            export AMS_ENDPOINT="https://${AMS_HOST}/ams"
            ams-ping
        done
    else
        log INFO "Skipping ams-ping due to --noping flag."
    fi
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"
setup_env

ctx AMS_CONTAINER

process_kube_compose
kube_deploy
ams_ping
