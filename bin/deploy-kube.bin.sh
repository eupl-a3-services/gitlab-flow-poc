#!/bin/bash

set -e

log INFO "GLAB_LOG: '${GLAB_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false
    __NOPING=false
    __SECRET=false
    __DELETE=false
    __DOWNSTREAM=false
    __HIDE_ENV_VALUES=false

    case "${GLAB_LOG}" in
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
            --secret) __SECRET=true ;;
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
        export AMS_ENV="${AMS_TRIGGER_JOB##*:}"
    else
        export AMS_ENV="${CI_JOB_NAME##*:}"
    fi
    export AMS_SPACE=${AMS_ENV}
    if [ "$AMS_PARTITION" != "unit" ] && [ "$AMS_PARTITION" != "downstream" ]; then
        export AMS_SPACE="${AMS_SPACE}-${AMS_SEGMENT}"
    fi

    export AMS_DEPLOY=$(date '+%y%m%d-%H%M%S')

    export KUBE_COMPOSE_NAME=kube-compose
    export KUBE_SPACE_NAME=kube-space
    export KUBE_NODE_NAME=kube-node
    export KUBE_EXT=yml
}

env_setup() {
    log INFO ENV: setup
    if [ "$AMS_PARTITION" != "downstream" ]; then
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

apply_secret(){
    if [[ "$__SECRET" == "true" ]]; then
        log INFO APPLY_SECRET: enable
        assert FILE kube-secret.env
        set -a && . kube-secret.env && set +a
    fi
}

kubeconfig_setup() {
    log INFO KUBECONFIG: setup
    current_dir="${KUBECONFIG_HOME}/${AMS_PROJECT}/${AMS_SPACE}"

    while true; do
        log DEBUG KUBECONFIG: check ${current_dir}
        found_file=$(find "$current_dir" -maxdepth 1 -type f -name "*.yml" 2>/dev/null | head -n 1 || true)

        if [[ -n "${found_file}" ]]; then
            log INFO KUBECONFIG: ${found_file}
            export KUBECONFIG="${found_file}"
            return 0
        fi

        if [[ "${current_dir}" == "$KUBECONFIG_HOME" ]]; then
            log ERROR "No *.yml file found in any parent directory from ${KUBECONFIG_HOME}/${AMS_PROJECT}/${AMS_SPACE} upwards."
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

kube_node() {
    log INFO KUBE_NODE: setup
    
    if [[ -z "${KUBE_NODE}" ]]; then
        log INFO "KUBE_NODE: disabled - env KUBE_NODE is not defined, skipping node generation"
        return 0
    fi
    
    log INFO "KUBE_NODE: enabled - '${KUBE_NODE}'"

    local DIR=".kube"
    local AMS_NAME_ORIGIN=${AMS_NAME}
    for file in ${DIR}/'$'${KUBE_NODE_NAME}*.${KUBE_EXT}; do        
        AMS_NAME=${AMS_NAME_ORIGIN}
        KUBE_NODE_SUFFIX=$(basename "$file" | sed -E "s/^\\\$${KUBE_NODE_NAME}(.*)\.${KUBE_EXT}$/\1/")
        if [[ ${#KUBE_NODE_SUFFIX} -gt 1 && "${KUBE_NODE_SUFFIX}" == -* ]]; then
            AMS_NAME="${KUBE_NODE_SUFFIX:1}"
        fi
        #log INFO AMS_NAME: ${AMS_NAME}

        log INFO "KUBE_NODE_ENV: ${KUBE_NODE}"
        IFS=', ' read -r -a KUBE_NODE_ARRAY <<< "$KUBE_NODE"

        INPUT_FILE="${DIR}/\$${KUBE_NODE_NAME}.${AMS_NAME}.${KUBE_EXT}"
        OUTPUT_FILE="${DIR}/\$${KUBE_COMPOSE_NAME}.${AMS_NAME}.${KUBE_EXT}"

        if [[ -f "${INPUT_FILE}" ]]; then
            log INFO "KUBE_NODE_FILE: ${INPUT_FILE}"

            > "${OUTPUT_FILE}"

            for node in "${KUBE_NODE_ARRAY[@]}"; do
                echo "--- ## NODE: ${node}" >> "${OUTPUT_FILE}"

                sed "s/\${AMS_NODE}/${node}/g" "${INPUT_FILE}" >> "${OUTPUT_FILE}"
                echo "" >> "${OUTPUT_FILE}"
            done
            ansi-cat "${OUTPUT_FILE}"
        fi

    done
}

kube_space() {
    log INFO KUBE_SPACE: setup
    
    if [[ -z "${KUBE_SPACE}" ]]; then
        log INFO "KUBE_SPACE: disabled - env KUBE_SPACE is not defined, skipping space generation"
        return 0
    fi
    
    log INFO "KUBE_SPACE: enabled - '${KUBE_SPACE}'"

    local DIR=".kube"
    local AMS_NAME_ORIGIN=${AMS_NAME}

    log INFO "KUBE_SPACE_ENV: ${KUBE_SPACE}"
    IFS=', ' read -r -a KUBE_SPACE_ARRAY <<< "$KUBE_SPACE"

    for space in "${KUBE_SPACE_ARRAY[@]}"; do
        log INFO "  Processing SPACE: ${space}"
        if ! kubectl get namespace "ns-${space}" > /dev/null 2>&1; then
            ansi-cmd kubectl create namespace "ns-${space}"
            log INFO "    Namespace 'ns-${space}' has been created."
        else
            log INFO "    Namespace 'ns-${space}' already exists."
        fi
    done

    for file in ${DIR}/'$'${KUBE_SPACE_NAME}*.${KUBE_EXT}; do        
        AMS_NAME=${AMS_NAME_ORIGIN}
        KUBE_SPACE_SUFFIX=$(basename "$file" | sed -E "s/^\\\$${KUBE_SPACE_NAME}(.*)\.${KUBE_EXT}$/\1/")
        if [[ ${#KUBE_SPACE_SUFFIX} -gt 1 && "${KUBE_SPACE_SUFFIX}" == .* ]]; then
            AMS_NAME="${KUBE_SPACE_SUFFIX:1}"
        fi

        INPUT_FILE="${DIR}/\$${KUBE_SPACE_NAME}.${AMS_NAME}.${KUBE_EXT}"
        OUTPUT_FILE="${DIR}/\$${KUBE_COMPOSE_NAME}.${AMS_NAME}.${KUBE_EXT}"

        if [[ -f "${INPUT_FILE}" ]]; then
            log INFO "KUBE_SPACE_FILE: ${INPUT_FILE}"

            > "${OUTPUT_FILE}"

            for space in "${KUBE_SPACE_ARRAY[@]}"; do
                echo "--- ## SPACE: ${space}" >> "${OUTPUT_FILE}"
                sed "s/\${AMS_SPACE}/${space}/g" "${INPUT_FILE}" >> "${OUTPUT_FILE}"
                echo "" >> "${OUTPUT_FILE}"
            done
            ansi-cat "${OUTPUT_FILE}"
        fi
    done
}


kube_compose() {
    PROCESSED=-processed
    declare -gA AMS_HOSTS=()

    #export request_uri='$request_uri'       # used for snippet redirect in ingress
    export hostname='${HOSTNAME}'           # used for stateless pod name
    
    DIR=$(pwd)

    [ -d .kube ] && {
        log INFO "Using configuration from .kube directory – copying files to current directory"
        cp -r .kube/* .
    }

    assert GLOB '\$'${KUBE_COMPOSE_NAME}*.${KUBE_EXT}

    local REQUEST_NAME=${AMS_NAME}-${AMS_REVISION}-${AMS_SPACE}
    local REQUEST_FILE=/tmp/${REQUEST_NAME}.kube
    local SESSION_REQUEST_NAME="${REQUEST_NAME}.kube-session-request"
    local SESSION_REQUEST_FILE="/cache-volume/session-request/${SESSION_REQUEST_NAME}"
    > ${REQUEST_FILE}
    > ${KUBE_COMPOSE_NAME}.${KUBE_EXT}

    local AMS_NAME_ORIGIN=${AMS_NAME}
    for file in ${DIR}/'$'${KUBE_COMPOSE_NAME}*.${KUBE_EXT}; do
        local RELATIVE_FILE="${file#$(pwd)/}"
        
        AMS_NAME=${AMS_NAME_ORIGIN}
        KUBE_COMPOSE_SUFFIX=$(basename "$file" | sed -E "s/^\\\$${KUBE_COMPOSE_NAME}(.*)\.${KUBE_EXT}$/\1/")
        if [[ ${#KUBE_COMPOSE_SUFFIX} -gt 1 && "${KUBE_COMPOSE_SUFFIX}" == .* ]]; then
            AMS_NAME="${KUBE_COMPOSE_SUFFIX:1}"
        fi
        log INFO AMS_NAME: ${AMS_NAME}

        ansi-lint-env ${RELATIVE_FILE} "$__HIDE_ENV_VALUES"
        if [ "${__HIDE_ENV_VALUES}" = "true" ]; then
            ansi-lint-env ${RELATIVE_FILE} >> ${REQUEST_FILE}
            log INFO "LINT-ENV for \"${RELATIVE_FILE}\" is stored in \"${SESSION_REQUEST_FILE}\""
        fi
        
        while IFS= read -r line; do
            if [[ "$line" == !* ]]; then
                log ERROR Found obsolete eval functionality. This is no longer supported. "eval in: ${file}"
                exit 10
            fi
        done < <(grep '^!' "$file")

        VARS=$(grep -oE '\$\{[A-Z_][A-Z0-9_]*\}|\$[A-Z_][A-Z0-9_]*' "$file" \
        | sed -E 's/^\$\{?([A-Z_][A-Z0-9_]*)\}?$/\1/' \
        | sort -u \
        | xargs -I{} echo -n '$'{}' ')

        GENERATED_FILE="${file%.yml}${PROCESSED}.${KUBE_EXT}"

        envsubst "$VARS" < "$file" > "${GENERATED_FILE}"

        local AMS_HOST=$(yq '. | select(.kind == "Ingress") | .spec.rules[0].host' "${GENERATED_FILE}" 2>/dev/null)

        log INFO AMS_NAME: ${AMS_NAME}
        log INFO AMS_HOST: ${AMS_HOST}

        if [[ -n "${AMS_HOST}" && "${AMS_HOST}" != "null" ]]; then
            AMS_HOSTS["$AMS_NAME"]="${AMS_HOST}"
        fi

        original_file_name=$(basename "${GENERATED_FILE}" | sed "s/${PROCESSED}//")
        echo "--- # FILE: $original_file_name" >> ${KUBE_COMPOSE_NAME}.${KUBE_EXT}
        cat "${GENERATED_FILE}" >> ${KUBE_COMPOSE_NAME}.${KUBE_EXT}
        echo "" >> ${KUBE_COMPOSE_NAME}.${KUBE_EXT}
    done

    rm -f $DIR/*${PROCESSED}.${KUBE_EXT}
    if [ "${__HIDE_ENV_VALUES}" = "true" ]; then
        ansi-cat "${KUBE_COMPOSE_NAME}.${KUBE_EXT}" >> ${REQUEST_FILE}

        rm -f "${SESSION_REQUEST_FILE}"
        zip -j -P "${PDS_TOKEN}" "${SESSION_REQUEST_FILE}" "${REQUEST_FILE}"

        log INFO "KUBE_SESSION_REQUEST_FILE is stored in \"${SESSION_REQUEST_FILE}\""
    else
        ansi-cat "${KUBE_COMPOSE_NAME}.${KUBE_EXT}"
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
    export ANSI_HIGHLIGHT="created:32,configured:32,restarted:32,unchanged:33,Warning:33,invalid:31,error:31,Error:31"
    log INFO KUBE_NAMESPACE=${KUBE_NAMESPACE}

    if ! kubectl get namespace "${KUBE_NAMESPACE}" > /dev/null 2>&1; then
        ansi-cmd kubectl create namespace "${KUBE_NAMESPACE}"
        log INFO "Namespace '${KUBE_NAMESPACE}' has been created."
    else
        log INFO "Namespace '${KUBE_NAMESPACE}' already exists."
    fi

    if [ "$__DELETE" = true ]; then
        log INFO "Deleting Kubernetes resources in context '$KUBE_CURRENT_CONTEXT' using kubectl delete"
        kubectl delete --ignore-not-found -f ${KUBE_COMPOSE_NAME}.${KUBE_EXT} 2>&1 | \
        sed \
            -e $'s/deleted/\033[32m&\033[0m/g'
    fi

    ansi-cmd kubectl apply -f ${KUBE_COMPOSE_NAME}.${KUBE_EXT}

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
        . ansi-array AMS_HOSTS
        for name in "${!AMS_HOSTS[@]}"; do
            export AMS_NAME="$name"
            log INFO "Pinging AMS_NAME=$AMS_NAME"
            
            # Priame priradenie hosta z YAML súboru
            export AMS_HOST="${AMS_HOSTS[$name]}"
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
apply_secret

kubeconfig_setup

kube_info
kube_node
kube_space
kube_compose
kube_deploy

ams_ping
