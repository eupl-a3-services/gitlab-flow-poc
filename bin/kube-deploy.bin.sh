#!/bin/bash

set -e

log INFO "GLF_LOG: '${GLF_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false
    __NOPING=false
    __DELETE=false
    __DOWNSTREAM=false
    __HIDE_ENV_VALUES=false

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
            --delete) __DELETE=true ;;
            --noping) __NOPING=true ;;
            --downstream) __DOWNSTREAM=true ;; 
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

    if [ "$__DOWNSTREAM" = true ]; then
        AMS_PARTITION=downstream
        __HIDE_ENV_VALUES=true
        env2dir DIR_KUBE
    fi    
}

space_setup() {
    if [ "$AMS_PARTITION" == "downstream" ]; then
        assert ENV AMS_TRIGGER_JOB
        export AMS_SPACE="${AMS_TRIGGER_JOB##*:}"
    else
        export AMS_SPACE="${CI_JOB_NAME##*:}"
    fi
    if [ "$AMS_PARTITION" != "unit" ] && [ "$AMS_PARTITION" != "downstream" ]; then
        export AMS_SPACE="${AMS_SPACE}-${AMS_SEGMENT}"
    fi

    export AMS_DEPLOY=$(date '+%y%m%d-%H%M%S')

    case "${AMS_PARTITION}" in
        unit|downstream)
            export AMS_AREA=""
            ;;
        zone)
            export AMS_AREA="-${AMS_SPACE}"
            ;;
        shared)
            export AMS_AREA="-${AMS_SEGMENT}"
            ;;
        *)
            export AMS_AREA="-no-area"
            ;;
    esac

    export KUBE_COMPOSE_NAME=kube-compose
    export KUBE_COMPOSE_EXT=yml
}

env_setup() {
    log INFO ENV: setup
    if [ "$AMS_PARTITION" != "unit" ] && [ "$AMS_PARTITION" != "downstream" ]; then
        #if [[ -z ${AMS_SEGMENT} || ${AMS_SEGMENT} == no* ]]; then
        #    log ERROR "The value \"${AMS_SEGMENT}\" of AMS_SEGMENT is invalid. Please provide a valid segment."
        #    exit 1
        #fi
        if [[ ! -f "${ENV_HOME}/${AMS_SPACE}.env" ]]; then
            log ERROR "Configuration file \"${ENV_HOME}/${AMS_SPACE}.env\" not found. The space \"${AMS_SPACE}\" is not properly configured."
            exit 2
        fi
        log INFO ENV: ${ENV_HOME}/${AMS_SPACE}.env
        if [ "$__DEBUG" = true ]; then
            ansi-cat ${ENV_HOME}/${AMS_SPACE}.env
        fi
        set -o allexport
        source ${ENV_HOME}/${AMS_SPACE}.env
        
        ctx ENV
    fi
    if [ "$AMS_PARTITION" == "downstream" ]; then
        assert ENV PDS_TOKEN
        assert DIR /cache-volume/session-request
        ENV_FILE=/cache-volume/session-vault/${AMS_SPACE}.env-session-vault
        assert FILE ${ENV_FILE}

        set -o allexport
        unzip -o -P "$PDS_TOKEN" "$ENV_FILE" -d .env-session-vault

        for file in .env-session-vault/*.env; do
            [ -f "$file" ] && source "$file"
        done

        ctx ENV
    fi

}

kubeconfig_setup() {
    log INFO KUBECONFIG: setup
    current_dir="${KUBECONFIG_HOME}/${CI_PROJECT_PATH}/${AMS_SPACE}"

    while true; do
        log DEBUG KUBECONFIG: check ${current_dir}
        found_file=$(find "$current_dir" -maxdepth 1 -type f -name "*.yml" 2>/dev/null | head -n 1 || true)

        if [[ -n "${found_file}" ]]; then
            log INFO KUBECONFIG: ${found_file}
            export KUBECONFIG="${found_file}"
            return 0
        fi

        if [[ "${current_dir}" == "$KUBECONFIG_HOME" ]]; then
            log ERROR "No *.yml file found in any parent directory from ${KUBECONFIG_HOME}/${CI_PROJECT_PATH}/${AMS_SPACE} upwards."
            return 1
        fi

        current_dir=$(dirname "${current_dir}")
    done
}

kube_info() {
    ansi-cmd kubectl config get-contexts
    ansi-cmd kubectl get nodes
    ansi-cmd kubectl get namespaces
}

kube_compose() {
    PROCESSED=-processed
    AMS_NAMES_LOCAL=()

    export request_uri='$request_uri'       # used for snippet redirect in ingress
    export hostname='${HOSTNAME}'           # used for stateless pod name
    
    DIR=$(pwd)

    [ -d .kube ] && {
        log INFO "Using configuration from .kube directory – copying files to current directory"
        cp -r .kube/* .
    }

    assert GLOB '\$'${KUBE_COMPOSE_NAME}*.${KUBE_COMPOSE_EXT}

    local REQUEST_NAME=${AMS_NAME}-${AMS_REVISION}-${AMS_SPACE}
    local REQUEST_FILE=/tmp/${REQUEST_NAME}.kube
    local SESSION_REQUEST_NAME="${REQUEST_NAME}.kube-session-request"
    local SESSION_REQUEST_FILE="/cache-volume/session-request/${SESSION_REQUEST_NAME}"
    > ${REQUEST_FILE}
    > ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}

    for file in $DIR/'$'${KUBE_COMPOSE_NAME}*.${KUBE_COMPOSE_EXT}; do
        local RELATIVE_FILE="${file#$(pwd)/}"
        ansi-lint-env ${RELATIVE_FILE} "$__HIDE_ENV_VALUES"
        if [ "${__HIDE_ENV_VALUES}" = "true" ]; then
            ansi-lint-env ${RELATIVE_FILE} >> ${REQUEST_FILE}
            log INFO "LINT-ENV for \"${RELATIVE_FILE}\" is stored in \"${SESSION_REQUEST_FILE}\""
        fi
        while IFS= read -r line; do
            if [[ "$line" == !* ]]; then
                COMMAND="$(echo "${line:2}" | tr -d '\n' | tr -d '\r' | xargs)"
                eval "$COMMAND"
            fi
        done < <(grep '^!' "$file")

        sed 's/^!/#  EVAL:/' "$file" | envsubst > "${file%.yml}${PROCESSED}.${KUBE_COMPOSE_EXT}"

        if [[ ! " ${AMS_NAMES_LOCAL[@]} " =~ " ${AMS_NAME} " ]]; then
            AMS_NAMES_LOCAL+=("${AMS_NAME}")
        fi
    done

    for processed_file in $(ls $DIR/*${PROCESSED}.${KUBE_COMPOSE_EXT} | sort); do
        echo "---" >> ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}
        original_file_name=$(basename "$processed_file" | sed "s/${PROCESSED}//")
        echo "## FILE: $original_file_name" >> ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}
        cat "$processed_file" >> ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}
        echo "" >> ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}
    done

    rm -f $DIR/*${PROCESSED}.${KUBE_COMPOSE_EXT}
    if [ "${__HIDE_ENV_VALUES}" = "true" ]; then
        ansi-cat "${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}" >> ${REQUEST_FILE}

        rm -f "${SESSION_REQUEST_FILE}"
        zip -j -P "${PDS_TOKEN}" "${SESSION_REQUEST_FILE}" "${REQUEST_FILE}"

        log INFO "KUBE_SESSION_REQUEST_FILE is stored in \"${SESSION_REQUEST_FILE}\""
    else
        ansi-cat "${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}"
    fi
    
    if [[ -z "${AMS_NAMES[*]}" ]]; then
        AMS_NAMES=("${AMS_NAMES_LOCAL[@]}")
    fi
}

kube_deploy() {
    assert FILE ${KUBECONFIG}
    KUBE_CURRENT_CONTEXT=$(kubectl config current-context)

    if [[ -z "${AMS_SPACE}" ]]; then
        log ERROR "AMS_SPACE is empty. Aborting."
        exit 1
    fi

    KUBE_NAMESPACE="ns-${AMS_SPACE}"
    export ANSI_HIGHLIGHT="created:32,configured:32,restarted:32,unchanged:33,invalid:31,error:31"
    log INFO KUBE_NAMESPACE=${KUBE_NAMESPACE}

    if ! kubectl get namespace "${KUBE_NAMESPACE}" > /dev/null 2>&1; then
        log INFO "Namespace '${KUBE_NAMESPACE}' does not exist."
        ansi-cmd kubectl create namespace "${KUBE_NAMESPACE}"

        assert ENV GITLAB_REGISTRY_USER
        assert ENV GITLAB_REGISTRY_TOKEN
        ansi-cmd kubectl create secret docker-registry gitlab-registry-secret \
            --docker-server=registry.gitlab.com \
            --docker-username=${GITLAB_REGISTRY_USER} \
            --docker-password=${GITLAB_REGISTRY_TOKEN} \
            -n "${KUBE_NAMESPACE}"
    fi

    if [ "$__DELETE" = true ]; then
        log INFO "Deleting Kubernetes resources in context '$KUBE_CURRENT_CONTEXT' using kubectl delete"
        kubectl delete --ignore-not-found -f ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT} 2>&1 | \
        sed \
            -e $'s/deleted/\033[32m&\033[0m/g'
    fi

    ansi-cmd kubectl apply -f ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}

    for deployment in $(echo "$output" | grep "deployment.apps" | awk '{print $1}' | cut -d '/' -f 2); do
        log INFO "DEPLOYMENT: $deployment"
        if echo "$output" | grep -q "deployment.apps/$deployment.*changed"; then
            log INFO "Rollout restart for $deployment"
            ansi-cmd kubectl rollout restart deployment $deployment -n "${KUBE_NAMESPACE}"
        else
            log INFO "No change for $deployment, skipping rollout"
        fi
    done

}

ams_ping() {
    if [ "$__NOPING" = false ]; then
        # assert ENV AMS_DOMAIN
        . ansi-array AMS_NAMES
        for name in "${AMS_NAMES[@]}"; do
            export AMS_NAME="$name"
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

space_setup

ctx AMS_DEPLOY

env_setup

kubeconfig_setup

kube_info
kube_compose
kube_deploy

ams_ping
