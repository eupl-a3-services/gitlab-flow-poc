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
        . setx INSPECT
    fi

    if [ "$__DEBUG" = true ]; then
        source log level DEBUG
    fi
}

increment_minor_version() {
    local VERSION=$1
    local MAJOR=$(echo "${VERSION}" | cut -d '.' -f 1)
    local MINOR=$(echo "${VERSION}" | cut -d '.' -f 2)
    local PATCH=$(echo "${VERSION}" | cut -d '.' -f 3 | sed 's/-.*//')

    NEW_MINOR=$((MINOR + 1))

    echo "${MAJOR}.${NEW_MINOR}.0-SNAPSHOT"
}

ams_dist() {
    local VERSION=$1
    if [[ "${VERSION}" == *-* ]]; then
        BASE_VERSION=$(echo "${VERSION}" | cut -d '-' -f 1)
        API_VERSION=$(increment_minor_version "${BASE_VERSION}")
    else
        API_VERSION="${VERSION}"
    fi

    echo "${API_VERSION}"
}

ams_resource() {
    if [ -n "$CI_COMMIT_TAG" ]; then
        echo "tag"
    elif [[ -z "${CI_COMMIT_BRANCH}" ]]; then
        echo "undefined"
    elif [[ "${CI_COMMIT_BRANCH}" == "${CI_DEFAULT_BRANCH}" ]]; then
        echo "default"
    elif [[ "${CI_COMMIT_REF_PROTECTED}" == "true" ]]; then
        echo "protected"
    else
        echo "experimental"
    fi
}

ams_rollout() {
    export AMS_SEGMENT="no-segment"
    export AMS_RELEASE="no-release"
    export AMS_BUSINESS="no-business"
    export AMS_PARTITION="no-partition"

    if [[ "${AMS_RESOURCE}" == "protected" || "${AMS_RESOURCE}" == "tag" || "${AMS_RESOURCE}" == "default" ]]; then
        if [[ "${AMS_ROLLOUT}" =~ ^([@a-z0-9-]+)\/([^\/]+)\/([^\/]+)$ ]]; then
            export AMS_SEGMENT="${BASH_REMATCH[1]}"
            export AMS_RELEASE="${BASH_REMATCH[2]}"
            export AMS_BUSINESS="${BASH_REMATCH[3]}"

            if [[ "${AMS_SEGMENT}" == "@" ]]; then
                export AMS_PARTITION="service"
#            elif [[ "${AMS_SEGMENT}" == "-" ]]; then
#                export AMS_PARTITION="core"
            elif [[ "${AMS_SEGMENT}" =~ ^[0-9]+$ ]]; then
                export AMS_PARTITION="zone"
            elif [[ "${AMS_SEGMENT}" =~ ^[a-z]$ ]]; then
                export AMS_PARTITION="shared"
            fi
        else
            export AMS_SEGMENT="no-regex-${AMS_RESOURCE}"
            export AMS_RELEASE="no-regex-${AMS_RESOURCE}"
            export AMS_BUSINESS="no-regex-${AMS_RESOURCE}"
            export AMS_PARTITION="no-regex-${AMS_RESOURCE}"
        fi
    fi
}

env_files() {
    ORIGIN_ENV=origin.env
    AMS_ORIGIN_ENV=ams-origin.env

    log DEBUG "Exporting environment variables to ${ORIGIN_ENV}"
    env | sort > ${ORIGIN_ENV}
    if [ "${AMS_LOG_LEVEL}" = "DEBUG" ]; then
        cat ${ORIGIN_ENV}
    fi

    if [ -n "$CI_COMMIT_TAG" ]; then
        export AMS_REVISION="$CI_COMMIT_TAG"
    elif [ -d .git ]; then
        git config --global --add safe.directory ${PWD}
        if [ "${AMS_LOG_LEVEL}" = "DEBUG" ]; then
            git fetch --unshallow || git fetch
        else
            git fetch --unshallow > /dev/null 2>&1 || git fetch > /dev/null 2>&1
        fi
        export AMS_REVISION=$(git describe --tags 2>/dev/null || echo "no-tag")
    else
        export AMS_REVISION="no-git"
    fi

    export AMS_NAME=${CI_PROJECT_NAME}
    export AMS_ROLLOUT=${CI_COMMIT_BRANCH}
    export AMS_TRIGGER=${CI_PIPELINE_SOURCE}
    export AMS_REVISION=${AMS_REVISION}
    export AMS_BUILD=`date '+%y%m%d-%H%M%S'`
    export AMS_DIST=$(ams_dist "${AMS_REVISION}")
    export AMS_RESOURCE=$(ams_resource)

    if [[ "${CI_COMMIT_BRANCH}" == "${CI_DEFAULT_BRANCH}" ]]; then
        if [[ "${AMS_PARTITION}" == "service" ]]; then
            assert ENV ROLLOUT_DEFAULT_SERVICE
            export AMS_ROLLOUT="${ROLLOUT_DEFAULT_SERVICE}"
        elif [[ "${AMS_PARTITION}" == "shared" ]]; then
            assert ENV ROLLOUT_DEFAULT_SHARED
            export AMS_ROLLOUT="${ROLLOUT_DEFAULT_SHARED}"
        else
            assert ENV ROLLOUT_DEFAULT_ZONE
            export AMS_ROLLOUT="${ROLLOUT_DEFAULT_ZONE}"
        fi
    fi

    assert ENV ROLLOUT_HOME

    SHA_ROLLOUT=${ROLLOUT_HOME}/${CI_COMMIT_SHA}

    if [ -z "${AMS_ROLLOUT}" ]; then
        if [ -f "${SHA_ROLLOUT}" ]; then
            AMS_ROLLOUT=$(cat "${SHA_ROLLOUT}")
            log INFO "The rollout environment variable AMS_ROLLOUT has been updated with the value: \"${AMS_ROLLOUT}\" from the file: \"${SHA_ROLLOUT}\""
        else
            log ERROR "The rollout file \"${SHA_ROLLOUT}\" was not found"
            log ERROR "Check COMMIT_PIPELINES: ${CI_PROJECT_URL}/-/commit/${CI_COMMIT_SHA}/pipelines"
            exit 1
        fi
    else
        mkdir -p "$(dirname "${SHA_ROLLOUT}")"
        ROLLOUT_REMOVED_FILES_COUNT=$(find "${ROLLOUT_HOME}" -type f -mtime +7 -exec rm -f {} \; -print | wc -l)
        log INFO "Old rollout files older than 7 days have been removed. Total removed files: ${ROLLOUT_REMOVED_FILES_COUNT}"

        echo "$AMS_ROLLOUT" > "${SHA_ROLLOUT}"
        log INFO "The rollout file \"${SHA_ROLLOUT}\" has been created with the value: \"${AMS_ROLLOUT}\""
    fi

    ams_rollout

    cat << EOF > "${AMS_ORIGIN_ENV}"
AMS=${AMS}
AMS_NAME=${AMS_NAME}
AMS_REVISION=${AMS_REVISION}
AMS_DIST=${AMS_DIST}
AMS_BUILD=${AMS_BUILD}
AMS_SEGMENT=${AMS_SEGMENT}
AMS_PARTITION=${AMS_PARTITION}
AMS_RELEASE=${AMS_RELEASE}
AMS_BUSINESS=${AMS_BUSINESS}
AMS_ROLLOUT=${AMS_ROLLOUT}
AMS_TRIGGER=${AMS_TRIGGER}
AMS_RESOURCE=${AMS_RESOURCE}
EOF

    log DEBUG "Contents of the '${AMS_ORIGIN_ENV}' file:"
    log DEBUG "$(cat ./${AMS_ORIGIN_ENV})"

    log DEBUG "Contents of the '${ORIGIN_ENV}' file:"
    log DEBUG "$(cat ./${ORIGIN_ENV})"

    log INFO "Environment files ['${ORIGIN_ENV}', '${AMS_ORIGIN_ENV}'] have been created"
}

store_ci() {
    log INFO "Storing CI ..."
    if [ -n "$CI_COMMIT_BRANCH" ] && [ "${CI_COMMIT_REF_PROTECTED}" == "true" ]; then
        assert ENV CI_HOME
        mkdir -p "${CI_HOME}/${CI_COMMIT_BRANCH}"
        cat .gitlab-ci.yml > "${CI_HOME}/${CI_COMMIT_BRANCH}/.gitlab-ci.yml"
        log INFO "CI file [${CI_HOME}/${CI_COMMIT_BRANCH}/.gitlab-ci.yml] have been created"
    else
        if [ -z "$CI_COMMIT_BRANCH" ]; then
            log WARN "CI_COMMIT_BRANCH is not defined. CI file was not created."
        elif [ "${CI_COMMIT_REF_PROTECTED}" != "true" ]; then
            log WARN "CI_COMMIT_REF_PROTECTED is not 'true'. CI file was not created."
        fi
    fi
}

ctx AHS_ORIGIN

argument_config "$@"
env_files
store_ci

ctx AMS_ORIGIN
