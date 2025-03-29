#!/bin/bash

set -e

log INFO "AMS_LOG: '${AMS_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false
    __SERVICE=false

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
            --service) __SERVICE=true ;;
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

    if [ "$__SERVICE" = true ]; then
        mkdir -p service
        cp /opt/gitlab-flow/dist/ams-service service/ams-service
        cp /opt/gitlab-flow/dist/ams-service-alpine service/ams-service-alpine
    fi
}

release() {
    log DEBUG AMS=$AMS
    log DEBUG AMS_NAME=$AMS_NAME
    log DEBUG AMS_REVISION=$AMS_REVISION
    log DEBUG AMS_BUILD=$AMS_BUILD
    log DEBUG CI_REGISTRY_USER=$CI_REGISTRY_USER
    log DEBUG CI_REGISTRY_PASSWORD=$CI_REGISTRY_PASSWORD
    log DEBUG CI_REGISTRY=$CI_REGISTRY
    log DEBUG CI_REGISTRY_IMAGE=$CI_REGISTRY_IMAGE

    export AMS_IMAGE_REGISTRY=${CI_REGISTRY_IMAGE}/${AMS_NAME}:${AMS_REVISION}
    log DEBUG AMS_IMAGE_REGISTRY=${AMS_IMAGE_REGISTRY}

    echo "${CI_REGISTRY_PASSWORD}" | docker login -u "${CI_REGISTRY_USER}" --password-stdin ${CI_REGISTRY}
    
    docker build -f Dockerfile \
    --build-arg "AMS=${AMS}" \
    --build-arg "AMS_NAME=${AMS_NAME}" \
    --build-arg "AMS_REVISION=${AMS_REVISION}" \
    --build-arg "AMS_BUILD=${AMS_BUILD}" \
    --no-cache -t ${AMS_IMAGE_REGISTRY} .
    docker push ${AMS_IMAGE_REGISTRY}

    export AMS_IMAGE_LAYERS=$(docker inspect ${AMS_IMAGE_REGISTRY} | jq '.[].RootFS.Layers | length')
    export AMS_IMAGE_SIZE=$(docker inspect --format='{{.Size}}' ${AMS_IMAGE_REGISTRY} | awk '{print $1/1024/1024 " MB"}')
}

ctx AMS_HUB
ctx AMS_ORIGIN

argument_config "$@"
release

ctx AMS_IMAGE
