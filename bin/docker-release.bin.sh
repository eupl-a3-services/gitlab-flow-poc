#!/bin/bash

set -e

log INFO "GLF_LOG: '${GLF_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false
    __SERVICE=false

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
            --service) __SERVICE=true ;;
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

    echo "${CI_REGISTRY_PASSWORD}" | docker login -u "${CI_REGISTRY_USER}" --password-stdin ${CI_REGISTRY} 2>&1 \
        | grep -v -e 'Your password will be stored unencrypted' \
                  -e 'Configure a credential helper to remove this warning'
    
    docker info > docker-info.yml
    ansi-cat docker-info.yml

    assert FILE ./.docker/${AMS_NAME}/Dockerfile

    cp ./.docker/${AMS_NAME}/Dockerfile .

    ansi-cat Dockerfile

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

AMS_NAME=${CI_JOB_NAME##*:}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"
release

ctx AMS_IMAGE
