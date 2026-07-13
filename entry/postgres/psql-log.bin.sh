#!/bin/bash
#SCRIPT_NAME=/usr/local/bin/psql-log; cat <<"EOS" > ${SCRIPT_NAME}

if [ -z "$AMS_LOG_DIR" ] || [ -z "$AMS_NAME" ]; then
    echo "Error: AMS_LOG_DIR or AMS_NAME is not set."
    exit 1
fi

log_file="${AMS_LOG_DIR}/${AMS_NAME}-$(date '+%y-%m').log"

if [ ! -f "$log_file" ]; then
    echo "Log file '${log_file}' does not exist. Waiting for it to be created..."
    touch "$log_file"
fi

echo "Monitoring log file: $log_file"
tail -f "$log_file"

exit 0
EOS
chmod 755 ${SCRIPT_NAME}
${SCRIPT_NAME}