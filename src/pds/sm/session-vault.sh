#!/bin/bash

zip_secure_session() {
  printc CYAN "SM" ${FUNCNAME} $1

  local source_dir="$1"
  local session_suffix="$2"

  find "$source_dir" -type f | while read -r FILE_PATH; do
    FILE_NAME=$(basename "${FILE_PATH}")
    FILE_BASE="${FILE_NAME%.*}"
    SESSION_NAME="${FILE_BASE//./-}.${session_suffix}-session-vault"
    SESSION_FILE="/cache-volume/session-vault/${SESSION_NAME}"

    zip -j -P "${PDS_TOKEN}" "${SESSION_FILE}" "${FILE_PATH}"
  done
}

rm -rf /cache-volume/session-vault/*
zip_secure_session "/secure-storage/key" "key"
zip_secure_session "/secure-storage/env" "env"