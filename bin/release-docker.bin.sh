#!/bin/bash

set -e

log INFO "GLAB_LOG: '${GLAB_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false
    __SERVICE=false
    __OPT_ENTRY_AMS=false
    __OPT_ENTRY_POSTGRES=false
    __OPT_ENTRY_KEYCLOAK=false
    __OPT_ENTRY_KONG=false

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
            --inspect)              __INSPECT=true ;;
            --debug)                __DEBUG=true ;;
            --service)              __SERVICE=true ;;
            --opt-psql-kit)         __OPT_PSQL_KIT=true ;;
            --opt-entry-ams)        __OPT_ENTRY_AMS=true ;;
            --opt-entry-postgres)   __OPT_ENTRY_POSTGRES=true ;;
            --opt-entry-keycloak)   __OPT_ENTRY_KEYCLOAK=true ;;
            --opt-entry-kong)       __OPT_ENTRY_KONG=true ;;
            *) log ERROR "Unknown parameter: $1"; exit 64 ;;
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
        log ERROR Option '--service' is deprecated. Use '--opt-entry-ams' instead.
        exit 1
    fi

    if [ "$__OPT_PSQL_KIT" = true ]; then
        log ERROR Option '--opt-psql-kit' is deprecated. Use '--opt-entry-postgres' instead.
        exit 1
    fi

    if [ "$__OPT_ENTRY_AMS" = true ]; then
        SRC_ENTRY="/opt/entry/ams"
        DST_ENTRY=".opt/entry/ams"

        mkdir -p "$DST_ENTRY"

        cp /opt/dist/ams-service                      $DST_ENTRY/ams-service
        cp /opt/dist/ams-service-alpine               $DST_ENTRY/ams-service-alpine
    fi

    if [ "$__OPT_ENTRY_POSTGRES" = true ]; then
        SRC_ENTRY="/opt/entry/postgres"
        DST_ENTRY=".opt/entry/postgres"

        mkdir -p "$DST_ENTRY"

        cp /opt/dist/ams-service-alpine             $DST_ENTRY/ams-service
        cp /opt/entry/.bin/log.bin.sh               $DST_ENTRY/log.bin.sh
        cp /opt/entry/.bin/entry-init.bin.sh        $DST_ENTRY/entry-init.bin.sh
        cp -a $SRC_ENTRY/.                          $DST_ENTRY/
    fi

    if [ "$__OPT_ENTRY_KEYCLOAK" = true ]; then
        SRC_ENTRY="/opt/entry/keycloak"
        DST_ENTRY=".opt/entry/keycloak"

        mkdir -p "$DST_ENTRY"

        cp /opt/dist/ams-service                    $DST_ENTRY/ams-service
        cp /opt/entry/.bin/log.bin.sh               $DST_ENTRY/log.bin.sh
        cp /opt/entry/.bin/entry-init.bin.sh        $DST_ENTRY/entry-init.bin.sh
        cp -a $SRC_ENTRY/.                          $DST_ENTRY/
    fi

    if [ "$__OPT_ENTRY_KONG" = true ]; then
        SRC_ENTRY="/opt/entry/kong"
        DST_ENTRY=".opt/entry/kong"

        mkdir -p "$DST_ENTRY"

        #cp /opt/dist/ams-service                    $DST_ENTRY/ams-service
        cp /opt/entry/.bin/log.bin.sh               $DST_ENTRY/log.bin.sh
        cp /opt/entry/.bin/entry-init.bin.sh        $DST_ENTRY/entry-init.bin.sh
        cp -a $SRC_ENTRY/.                          $DST_ENTRY/
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

    assert FILE ./.docker/Dockerfile.${AMS_NAME}

    cp ./.docker/Dockerfile.${AMS_NAME} ./Dockerfile

    ansi-cat Dockerfile

    docker buildx create --use

    docker buildx build -f Dockerfile \
    --build-arg "AMS=${AMS}" \
    --build-arg "AMS_NAME=${AMS_NAME}" \
    --build-arg "AMS_REVISION=${AMS_REVISION}" \
    --build-arg "AMS_BUILD=${AMS_BUILD}" \
    --platform linux/amd64 \
    --no-cache \
    -t ${AMS_IMAGE_REGISTRY} \
    --load \
    .

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
