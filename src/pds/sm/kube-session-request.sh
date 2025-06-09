#!/bin/bash

printc CYAN "SM" ${BASH_SOURCE[0]}

kube_session_request(){
    local REQUEST_DIR="/cache-volume/session-request"
    local TARGET_DIR="/secure-storage/kube"
    local EXTENSION=".kube-session-request"

    local COUNT=$(find "$REQUEST_DIR" -type f -name "*${EXTENSION}" | wc -l)

    if [ "${COUNT}" -eq 0 ]; then
        printc CYAN "INFO" "No pending kube session requests found."
        exit 0
    fi

    printc YELLOW "ENV_REQUEST_COUNT" ${COUNT}

    local OLDEST_FILE=$(find "${REQUEST_DIR}" -type f -name "*${EXTENSION}" -printf "%T@ %p\n" | sort -n | head -n 1 | cut -d' ' -f2-)

    printc BLUE "PROCESSING" "${OLDEST_FILE}"

    local BASE_NAME=$(basename "${OLDEST_FILE}")
    local UNZIP_TARGET="${TARGET_DIR}/${BASE_NAME%${EXTENSION}}.kube"

    unzip -o -P "$PDS_TOKEN" "${OLDEST_FILE}" -d "${TARGET_DIR}" >/dev/null

    if [[ -f "${UNZIP_TARGET}" ]]; then
        printc GREEN "EXTRACTED" "${UNZIP_TARGET}"
        if file "${UNZIP_TARGET}" | grep -q text; then
            printc CYAN "CONTENT"
            cat "${UNZIP_TARGET}"
        fi
    else
        printc RED "ERROR" "${UNZIP_TARGET}"
    fi

    rm -f "${OLDEST_FILE}"
    printc RED "CLEANED" "Removed original: ${OLDEST_FILE}"
}

kube_session_request