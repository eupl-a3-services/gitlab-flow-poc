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
repo_clone() {
    #A3_REPO_USER=
    #A3_REPO_EMAIL=
    #A3_REPO_TOKEN=
    #A3_CLASS_DIAGRAM=class-diagram.puml
   export A3_REPO_DIR=${A3_REPO_DIR:-a3-repo}
 
    req A3_REPO_USER A3_REPO_EMAIL A3_REPO_TOKEN A3_REPO_GIT A3_REPO_DIR A3_CLASS_DIAGRAM

    git config --global user.name "${A3_REPO_USER}"
    git config --global user.email "${A3_REPO_EMAIL}"
    git clone https://gitlab-ci-token:${A3_REPO_TOKEN}@${A3_REPO_GIT} ${A3_REPO_DIR}
}

repo_handler() {
    A3_PUML_DIR=${A3_REPO_DIR}/src/main/@/class-diagram/puml
    A3_PUML_PROPERTIES=${A3_PUML_DIR}/puml.properties

    if [ -n "$CI_COMMIT_TAG" ]; then
      A3_CLASS_DIAGRAM_PUML=cd-${AMS_REVISION%%-*}.puml
    else
      A3_CLASS_DIAGRAM_PUML=cd-${AMS_REVISION%%-*}-${CI_COMMIT_REF_NAME#a3-}.puml
    fi
    log VALUE A3_CLASS_DIAGRAM_PUML ${A3_CLASS_DIAGRAM_PUML}

    cp ${A3_CLASS_DIAGRAM} ${A3_PUML_DIR}/${A3_CLASS_DIAGRAM_PUML}

    A3_RECORD="$(date +"%y%m%d-%H%M%S"): ${A3_CLASS_DIAGRAM_PUML}"
    log VALUE A3_RECORD ${A3_RECORD}

    if grep -q "${A3_CLASS_DIAGRAM_PUML}" ${A3_PUML_PROPERTIES}; then
      sed -i "s/.*${A3_CLASS_DIAGRAM_PUML}.*/${A3_RECORD}/" ${A3_PUML_PROPERTIES}
      A3_GIT_MESSAGE="update class-diagram"
    else
      echo "${A3_RECORD}" >> ${A3_PUML_PROPERTIES}
      A3_GIT_MESSAGE="new class-diagram"
    fi
    log VALUE A3_GIT_MESSAGE ${A3_GIT_MESSAGE}

    ansi-cat ${A3_PUML_PROPERTIES}
}

repo_push() {
    cd ${A3_REPO_DIR}
    git add .
    if ! git diff-index --quiet HEAD --; then
        git commit -m "${A3_GIT_MESSAGE} ${A3_CLASS_DIAGRAM_PUML}"
        git push origin main
    else
        log WARN "No changes to commit"
    fi
}


ctx AMS_HUB
ctx AMS_ORIGIN

argument_config "$@"
repo_clone
repo_handler
repo_push
