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
        . setx INSPECT
    fi

    if [ "$__DEBUG" = true ]; then
        source log level DEBUG
    fi
}

setup_env() {
    export AMS_ENV=${CI_ENVIRONMENT_NAME}
    export AMS_SPACE=${AMS_ENV}

    if [ "$AMS_PARTITION" != "unit" ]; then
        if [[ -z ${AMS_SEGMENT} || ${AMS_SEGMENT} == no* ]]; then
            log ERROR "The value \"${AMS_SEGMENT}\" of AMS_SEGMENT is invalid. Please provide a valid segment."
            exit 1
        fi
        export AMS_SPACE="${AMS_ENV}-${AMS_SEGMENT}"
        
        if [[ ! -f "${ENV_HOME}/${AMS_SPACE}.env" ]]; then
            log ERROR "Configuration file \"${ENV_HOME}/${AMS_SPACE}.env\" not found. The space \"${AMS_SPACE}\" is not properly configured."
            exit 2
        fi
        log INFO ${ENV_HOME}/${AMS_SPACE}.env
        if [ "$__DEBUG" = true ]; then
            ansi-cat ${ENV_HOME}/${AMS_SPACE}.env
        fi
        set -o allexport
        source ${ENV_HOME}/${AMS_SPACE}.env
    fi

    export AMS_DEPLOY=$(date '+%y%m%d-%H%M%S')

    case "${AMS_PARTITION}" in
        unit)
            export AMS_AREA=""
            ;;
        zone)
            export AMS_AREA="-${AMS_ENV}-${AMS_SEGMENT}"
            ;;
        shared)
            export AMS_AREA="-${AMS_SEGMENT}"
            ;;
#        core)
#            export AMS_AREA=""
#            ;;
        *)
            export AMS_AREA="-no-area"
            ;;
    esac

    export KUBE_COMPOSE_NAME=kube-compose
    export KUBE_COMPOSE_EXT=yml
}

kube_info() {
    log INFO "kubectl config get-contexts"
    kubectl config get-contexts
    log INFO "get namespaces"
    kubectl get namespaces
    log INFO "get nodes -o wide"
    kubectl get nodes -o wide
    # kubectl api-resources -o wide
    # kubectl get crd
}

process_kube_compose() {
    PROCESSED=-processed
    AMS_NAMES_LOCAL=()

    export request_uri='$request_uri'       # used for snippet redirect in ingress
    export hostname='${HOSTNAME}'           # used for stateless pod name
    
    DIR=$(pwd)

    [ -d .kube ] && cp -r .kube/* .

    assert GLOB '$'${KUBE_COMPOSE_NAME}*.${KUBE_COMPOSE_EXT}

    > ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}

    for file in $DIR/'$'${KUBE_COMPOSE_NAME}*.${KUBE_COMPOSE_EXT}; do
        while IFS= read -r line; do
            if [[ "$line" == !* ]]; then
                COMMAND="$(echo "${line:2}" | tr -d '\n' | tr -d '\r' | xargs)"
                eval "$COMMAND"

                #log INFO AMS_NAME=${AMS_NAME}
                #if [[ -n "${AMS_NAME}" ]]; then
                #    log INFO add 
                #    AMS_NAMES_LOCAL+=("${AMS_NAME}")
                #fi
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
        -e $'s/invalid/\033[31m&\033[0m/g' \
        -e $'s/error/\033[31m&\033[0m/g'
}

run_kubectl() {
    local cmd="kubectl $*"

    log INFO "🚀 Running: $cmd"

    set +e
    output=$($cmd 2>&1)
    status=$?
    set -e

    highlight_output "$output"

    if [ $status -ne 0 ]; then
        log ERROR "❌ kubectl command failed: $cmd"
        return $status
    else
        log INFO "✅ kubectl command succeeded: $cmd"
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
    log INFO KUBE_NAMESPACE=${KUBE_NAMESPACE}

    if ! kubectl get namespace "${KUBE_NAMESPACE}" > /dev/null 2>&1; then
        log INFO "Namespace '${KUBE_NAMESPACE}' does not exist."
        run_kubectl create namespace "${KUBE_NAMESPACE}"

        assert ENV GITLAB_REGISTRY_USER
        assert ENV GITLAB_REGISTRY_TOKEN
        run_kubectl create secret docker-registry gitlab-registry-secret \
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

    log INFO "Applying Kubernetes resources in context '$KUBE_CURRENT_CONTEXT' using kubectl apply"
    run_kubectl apply -f ${KUBE_COMPOSE_NAME}.${KUBE_COMPOSE_EXT}

    for deployment in $(echo "$output" | grep "deployment.apps" | awk '{print $1}' | cut -d '/' -f 2); do
        log INFO "DEPLOYMENT: $deployment"
        if echo "$output" | grep -q "deployment.apps/$deployment.*changed"; then
            log INFO "Rollout restart for $deployment"
            run_kubectl rollout restart deployment $deployment -n env-${AMS_ENV}
        else
            log INFO "No change for $deployment, skipping rollout"
        fi
    done

}

ams_ping() {
    if [ "$__NOPING" = false ]; then
        assert ENV AMS_DOMAIN
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
setup_env

ctx AMS_CONTAINER

kube_info
process_kube_compose
kube_deploy
ams_ping
