#!/bin/bash

SERVICE_NAME="$1"

ENTRY_INIT_DIR=/opt/init/${AMS_SPACE}
ENTRY_INIT_LIMIT=30
SLEEP_INTERVAL=5

check_service_ready() {
    case "${SERVICE_NAME}" in
        Postgres)
            pg_isready -t 2 -U postgres > /dev/null 2>&1
            ;;
        Keycloak)
            (: </dev/tcp/localhost/8080) 2>/dev/null
            ;;
        Kafka)
            nc -z localhost 9092 > /dev/null 2>&1
            ;;
        Minio)
            curl -sf "http://localhost:9000/minio/health/live" > /dev/null 2>&1
            ;;
        Kong)
            curl -sf "http://localhost:8001/status" > /dev/null 2>&1
            ;;
        Redis)
            redis-cli ping > /dev/null 2>&1
            ;;
        *)
            return 0
            ;;
    esac
}

_main() {
    log HEAD "$0"

    if [ -z "${AMS_SPACE}" ]; then
        log ERROR "Environment variable AMS_SPACE is not set."
        exit 1
    fi

    ENTRY_INIT_COUNT=0

    log INFO "Waiting for ${SERVICE_NAME}, limit: ${ENTRY_INIT_LIMIT} (interval: ${SLEEP_INTERVAL}s)"
    
    while ! check_service_ready; do
        (( ENTRY_INIT_COUNT ++ ))

        if (( ENTRY_INIT_COUNT >= ENTRY_INIT_LIMIT )); then
          log ERROR "${SERVICE_NAME} is not ready after ${ENTRY_INIT_LIMIT} attempts"
          exit 1
        fi

        log WARN "${ENTRY_INIT_COUNT}/${ENTRY_INIT_LIMIT}: ${SERVICE_NAME} is not ready yet. Waiting for ${SLEEP_INTERVAL} seconds before retrying."
        sleep "${SLEEP_INTERVAL}"
    done

    log INFO "${SERVICE_NAME} became ready (after ${ENTRY_INIT_COUNT} attempts)"

    if [ -d "${ENTRY_INIT_DIR}" ]; then
        pushd "${ENTRY_INIT_DIR}" > /dev/null
        shopt -s nullglob
        ENTRY_INIT_FILES=( *.sh )
        ENTRY_INIT_TOTAL=${#ENTRY_INIT_FILES[@]}
        ENTRY_INIT_COUNT=0

        for ENTRY_INIT_FILE in "${ENTRY_INIT_FILES[@]}"; do
            (( ENTRY_INIT_COUNT++ ))

            log INFO "Executing script [${ENTRY_INIT_COUNT}/${ENTRY_INIT_TOTAL}]: ${ENTRY_INIT_FILE}"
            source "${ENTRY_INIT_FILE}"
        done

        popd > /dev/null
    else
        log ERROR "ENTRY_INIT_DIR not found: ${ENTRY_INIT_DIR}"
        exit 1
    fi

    log SUCCESS "$0: execution of all init scripts (${ENTRY_INIT_COUNT}): FINISHED SUCCESSFULLY"
}

_main
