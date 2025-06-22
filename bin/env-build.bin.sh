#!/bin/bash

set -e

log INFO "GLF_LOG: '${GLF_LOG}'. Options: [INSPECT, DEBUG]"

argument_config() {
    __INSPECT=false
    __DEBUG=false
    __CRYPT=false

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
            --crypt) __CRYPT=true ;;
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

env_build() {
    mkdir -p dist
    export ENV_REVISION=${AMS_REVISION}
    export ENV_BUILD=${AMS_BUILD}
    ENV_HEAD=`echo -e "AHS_REVISION=${AHS_REVISION}\nAHS_BUILD=${AHS_BUILD}\nENV_REVISION=${ENV_REVISION}\nENV_BUILD=${ENV_BUILD}\n"`
    (cd src && for FILE in *.env; do echo "${ENV_HEAD}" > ../dist/${FILE} && echo >> ../dist/${FILE} && cat ${FILE} >> ../dist/${FILE}; done)
}

env_build_crypt() {
    assert ENV PDS_TOKEN
    assert FILE /cache-volume/session-vault/ci-private.key-session-vault
    if ! unzip -p -P "${PDS_TOKEN}" /cache-volume/session-vault/ci-private.key-session-vault > /tmp/private.key; then
        log ERROR "Environment variable 'pds-token' is invalid. Aborting pipeline execution."
        exit 1
    fi

    ansi-cmd gpg --batch --import /tmp/private.key
    ansi-cmd gpg --list-secret-keys

    #git-crypt status
    #cat .gpg.env
    git-crypt unlock

    #git-crypt status
    ansi-cat .gpg.env
    if grep -q "GITCRYPT" .gpg.env; then
        log ERROR "Repo is still locked"
        exit 2
    else
        log INFO "Repo is successfully unlocked"
    fi

    mkdir -p dist
    export ENV_REVISION=${AMS_REVISION}
    export ENV_BUILD=${AMS_BUILD}
    ENV_HEAD=`echo -e "AHS_REVISION=${AHS_REVISION}\nAHS_BUILD=${AHS_BUILD}\nENV_REVISION=${ENV_REVISION}\nENV_BUILD=${ENV_BUILD}\n"`
    (cd src && for FILE in *.env; do echo "${ENV_HEAD}" > ../dist/${FILE} && echo >> ../dist/${FILE} && cat ${FILE} >> ../dist/${FILE}; done)
}

ctx AHS_ORIGIN
ctx AMS_ORIGIN

argument_config "$@"

if [ "$__CRYPT" = true ]; then
    env_build_crypt
else
    env_build
fi

ctx ENV