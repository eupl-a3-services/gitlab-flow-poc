#!/bin/bash

log HEAD "psql-backup @ ${PSQL_BACKUP_LIST}"

TOTAL_COUNT=$(wc -l < "${PSQL_BACKUP_LIST}")
CURRENT_COUNT=0

while IFS= read -r DB_NAME; do
    if [[ -n "${DB_NAME}" ]]; then
        CURRENT_COUNT=$((CURRENT_COUNT + 1))

        log DEBUG "[${CURRENT_COUNT}/${TOTAL_COUNT}] Starting backup for database: ${DB_NAME}"
        
        psql-sentinel "${DB_NAME}" b
        
        if [[ $? -eq 0 ]]; then
            log INFO "✅ Backup of the database ${DB_NAME} was successfully created."
        else
            log ERROR "❌ Error while backing up the database ${DB_NAME}."
        fi
    fi
done < "${PSQL_BACKUP_LIST}"