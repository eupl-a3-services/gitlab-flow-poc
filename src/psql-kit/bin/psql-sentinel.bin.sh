#!/bin/bash
#SCRIPT_NAME=/usr/local/bin/psql-sentinel; cat <<"EOS" > ${SCRIPT_NAME}

# SELECT * FROM pg_database;
# SELECT * FROM pg_roles;
# SELECT * FROM information_schema.role_table_grants;


PSQL_HOST=localhost
PSQL_USER=postgres
PSQL_ARCHIVE_DIR="${PSQL_ARCHIVE_DIR:-/var/lib/postgresql/data/.archive}"
PSQL_CACHE_FILE=/tmp/psql-sentinel.cache
SHARE_LINK_URL="${SHARE_LINK_URL:-https://share-link-1.ispo.dev}"
SHARE_LINK_TTL="${SHARE_LINK_TTL:-30m}"

function select_db() {
    local DATABASES DB_CHOICE ROW_FORMAT DB_NAME LB_ID DB_SIZE HEADER CHOICE EXIT_STATUS

    if [ -f "${PSQL_CACHE_FILE}" ] && [ -s "${PSQL_CACHE_FILE}" ]; then
        DATABASES=$(cat "${PSQL_CACHE_FILE}")
    else
        DATABASES=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;")

        >"${PSQL_CACHE_FILE}"

        DATABASES_INDEX=0
        DATABASES_COUNT=$(echo ${DATABASES} | wc -w)
        for DB_NAME in ${DATABASES}; do
            DATABASES_INDEX=$((DATABASES_INDEX + 1))
            echo -ne "\r\033[2K\033[1;33m<processing ... ${DATABASES_INDEX}/${DATABASES_COUNT}> DB: ${DB_NAME}\033[0m"
            if [ "${DB_NAME}" == "postgres" ]; then
                continue
            fi
            LB_ID=$(query_lb_id "${DB_NAME}")
            DB_SIZE=$(query_size "${DB_NAME}")
            DB_ROW_COUNT=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d "${DB_NAME}" -t -c "SELECT COALESCE(to_char(SUM(n_live_tup), 'FM999,999,999,999'), '0') FROM pg_stat_all_tables WHERE schemaname = 'public';")
            DB_TABLE_COUNT=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d "${DB_NAME}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_type='BASE TABLE' AND table_schema='public';")
            DB_VIEW_COUNT=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d "${DB_NAME}" -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='public';")
            DB_SEQUENCE_COUNT=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d "${DB_NAME}" -t -c "SELECT COUNT(*) FROM information_schema.sequences WHERE sequence_schema='public';")
            OWNER=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d postgres -t -c "SELECT pg_catalog.pg_get_userbyid(d.datdba) FROM pg_catalog.pg_database d WHERE d.datname = '${DB_NAME}';")
            DB_ACL=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d "${DB_NAME}" -t -c "SELECT datacl FROM pg_database WHERE datname = '${DB_NAME}';")
            DB_ACL="${DB_ACL//[$'\t ']/}"
            DB_ACL=${DB_ACL:-'-'} 
            DB_TIMESTAMP=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -t -c "SELECT COALESCE((SELECT to_char(query_start, 'YYYY-MM-DD HH24:MI:SS') FROM pg_stat_activity WHERE datname = '${DB_NAME}' ORDER BY query_start DESC LIMIT 1), '-')")
            DB_QUERY=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -t -c "SELECT COALESCE((SELECT query FROM pg_stat_activity WHERE datname = '${DB_NAME}' ORDER BY query_start DESC LIMIT 1), '-')")
            DB_QUERY=$(echo "${DB_QUERY}" | tr '\n' ' ')

            printf "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n" "${DB_NAME}" "${DB_SIZE}" "${LB_ID}" "${DB_ROW_COUNT}" "${DB_TABLE_COUNT}" "${DB_VIEW_COUNT}" "${DB_SEQUENCE_COUNT}" "${OWNER}" "${DB_TIMESTAMP}" "${DB_QUERY}" "${DB_ACL}" >>"${PSQL_CACHE_FILE}"
        done
    fi

    DB_CHOICE=()
    ROW_FORMAT='%-38s|%10s|%10s|%10s|%10s|%10s|%10s|%25s|%20s|%30s|%10s'
    while IFS='|' read -r DB_NAME DB_SIZE LB_ID DB_ROW_COUNT DB_TABLE_COUNT DB_VIEW_COUNT DB_SEQUENCE_COUNT OWNER DB_TIMESTAMP DB_QUERY DB_ACL; do
        DB_CHOICE+=("$(printf "${ROW_FORMAT}" "${DB_NAME}" "${DB_SIZE}" "${LB_ID}" "${DB_ROW_COUNT}" "${DB_TABLE_COUNT}" "${DB_VIEW_COUNT}" "${DB_SEQUENCE_COUNT}" "${OWNER}" "${DB_TIMESTAMP}" "${DB_QUERY}" "${DB_ACL}")")
    done <"${PSQL_CACHE_FILE}"

    echo -ne "\r\033[2K"
    DB_CHOICE+=("$(printf '\e[34m%-60s\e[0m' '«RELOAD»')")
    DB_CHOICE+=("$(printf '\e[34m%-60s\e[0m' '«PSQL_ARCHIVE_DIR»')")
    DB_CHOICE+=("$(printf '\e[34m%-60s\e[0m' '«EXIT»')")

    HEADER="$(printf "${ROW_FORMAT}" DB SIZE LB_ID ROW_COUNT TABLES VIEWS SEQUENCES OWNER LAST_TIMESTAMP LAST_QUERY ACCESS_CONTROL_LIST)"
    CHOICE=$(printf "%s\n" "${DB_CHOICE[@]}" | fzf --header "${HEADER}" --height 60% --reverse --ansi --prompt "<> DB: " --preview "key-value-preview \"${HEADER}\" {}")

    EXIT_STATUS=$?

    if [ $EXIT_STATUS = 0 ]; then
        DB_NAME=$(echo "${CHOICE}" | awk '{print $1}')
        log INFO DB: ${DB_NAME}
        if [ "${DB_NAME}" == "«PSQL_ARCHIVE_DIR»" ]; then
            mkdir -p "${PSQL_ARCHIVE_DIR}/remote"
            cd ${PSQL_ARCHIVE_DIR}/remote
        elif [ "${DB_NAME}" == "«RELOAD»" ]; then
            rm -f "${PSQL_CACHE_FILE}"
            select_db
        elif [ "${DB_NAME}" == "«EXIT»" ]; then
            exit
        else
            select_action ${DB_NAME}
        fi
    else
        log WARN DB: «CANCEL»
    fi
}

function preview() {
    local HEADER=$1
    local ROW=$2

    # Rozdelenie hlavičky a riadku na jednotlivé položky
    IFS='|' read -r -a KEYS <<< "${HEADER}"
    IFS='|' read -r -a VALUES <<< "${ROW}"

    for index in "${!KEYS[@]}"; do
        echo "${KEYS[index]}: ${VALUES[index]}"
    done
}

function query_lb_id(){
    local DB_NAME=$1
    local LB_ID TABLE_EXISTS

    TABLE_EXISTS=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d ${DB_NAME} -t -c "SELECT to_regclass('public.databasechangelog');")

    if [ -n "${TABLE_EXISTS}" ]; then
        LB_ID=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d ${DB_NAME} -t -c "SELECT id FROM databasechangelog ORDER BY length(id) DESC, id DESC LIMIT 1;" 2>/dev/null)
    fi
    
    if [ -z "${LB_ID}" ]; then
        LB_ID=0
    fi
    
    LB_ID=$(echo "${LB_ID}" | tr -d ' ')
    echo "${LB_ID}"
}

function query_size(){
    local DB_NAME=$1
    local DB_SIZE

    DB_SIZE=$(psql -U ${PSQL_USER} -h ${PSQL_HOST} -d postgres -t -c "SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));")
    DB_SIZE=$(echo "${DB_SIZE}" | tr -d ' ')
    echo "${DB_SIZE}"
}

function select_action() {
    local DB_NAME=$1 
    local LB_ID DB_SIZE IDENT ACTION_CHOICE CHOICE EXIT_STATUS ACTION_NAME

    LB_ID=$(query_lb_id "${DB_NAME}")
    DB_SIZE=$(query_size "${DB_NAME}")
    IDENT="<${DB_NAME}:${LB_ID}:${DB_SIZE}>"

    ACTION_CHOICE=()
    ACTION_CHOICE+=("$(printf '%-60s' '..')")
    ACTION_CHOICE+=("$(printf '%-60s' 'BACKUP')")
    ACTION_CHOICE+=("$(printf '%-60s' 'RESTORE')")
    ACTION_CHOICE+=("$(printf '%-60s' 'UPLOAD')")
    ACTION_CHOICE+=("$(printf '%-60s' 'WHIPEOUT')")
    ACTION_CHOICE+=("$(printf '%-60s' '«EXIT»')")

    CHOICE=$(printf "%s\n" "${ACTION_CHOICE[@]}" | fzf --height 60% --reverse --prompt "${IDENT} ACTION: " --preview "echo {}")

    EXIT_STATUS=$?

    if [ ${EXIT_STATUS} = 0 ]; then
        ACTION_NAME=$(echo "${CHOICE}" | awk '{print $1}')
        log INFO ${IDENT} ACTION: ${ACTION_NAME}
        if [ "${ACTION_NAME}" == "«EXIT»" ]; then
            log ${IDENT} SUCCESS «EXIT»
            exit
        elif [ "${ACTION_NAME}" == ".." ]; then
            select_db
        elif [ "${ACTION_NAME}" == "BACKUP" ]; then
            do_backup ${DB_NAME} m
            select_action ${DB_NAME}
        elif [ "${ACTION_NAME}" == "RESTORE" ]; then
            select_restore ${DB_NAME}
            select_action ${DB_NAME}
        elif [ "${ACTION_NAME}" == "UPLOAD" ]; then
            select_upload ${DB_NAME}
            select_action ${DB_NAME}
        elif [ "${ACTION_NAME}" == "WHIPEOUT" ]; then
            do_backup ${DB_NAME} w
            do_wipeout ${DB_NAME}
            select_action ${DB_NAME}
        fi
    else
        log ${IDENT} WARN ACTION: «CANCEL»
    fi
}

do_backup(){
    local DB_NAME=$1
    local TRIGGER=$2
    local LB_ID BACKUP_FILE BACKUP_SIZE

    LB_ID=$(query_lb_id "${DB_NAME}")
    
    printf -v LB_ID "%04d" "${LB_ID}"
    BACKUP_FILE="${PSQL_ARCHIVE_DIR}/${DB_NAME}/${DB_NAME}-${LB_ID}-$(date +'%y%m%d-%H%M%S')-${TRIGGER}.dump"
    log INFO BACKUP_FILE ${BACKUP_FILE}.tar.gz

    mkdir -p "${PSQL_ARCHIVE_DIR}/${DB_NAME}"
    pg_dump -U ${PSQL_USER} -O -d ${DB_NAME} > ${BACKUP_FILE}.sql
    {
        pushd "$(dirname "${BACKUP_FILE}")"
        tar -czf "$(basename "${BACKUP_FILE}").tar.gz" "$(basename "${BACKUP_FILE}.sql")"
        popd
    } > /dev/null 2>&1    
    rm "${BACKUP_FILE}.sql"

    BACKUP_SIZE=$(du -h ${BACKUP_FILE}.tar.gz | cut -f1)
    log INFO BACKUP_SIZE: ${BACKUP_SIZE}
}

choice_backup() {
    local DB_NAME=$1
    local LB_ID DB_SIZE CHOICE_TYPE IDENT FILES BACKUP_CHOICE CHOICE FILE DIR_NAME BASE_NAME FILE_SIZE
    
    LB_ID=$(query_lb_id "${DB_NAME}")
    DB_SIZE=$(query_size "${DB_NAME}")
    CHOICE_TYPE=$2
    IDENT="<${DB_NAME}:${LB_ID}:${DB_SIZE}>"

    FILES=($(find "${PSQL_ARCHIVE_DIR}" -type f | sort))

    if [ ${#FILES[@]} -eq 0 ]; then
        log ERROR "No backup files found in ${PSQL_ARCHIVE_DIR}."
        exit 1
    fi

    BACKUP_CHOICE=()
    BACKUP_CHOICE+=("$(printf '%-100s' '..')")
    for FILE in "${FILES[@]}"; do
        DIR_NAME=$(dirname "${FILE}")
        BASE_NAME=$(basename "${FILE}")

        DIR_NAME="${DIR_NAME#${PSQL_ARCHIVE_DIR}/}"
        FILE_SIZE=$(du -h "${FILE}" | cut -f1)

        printf -v formatted_entry "%-30s%-60s%10s" "${DIR_NAME}" "${BASE_NAME}" "${FILE_SIZE}"
        BACKUP_CHOICE+=("${formatted_entry}")
    done

    CHOICE=$(printf "%s\n" "${BACKUP_CHOICE[@]}" | fzf --height 60% --reverse --prompt "${IDENT} ${CHOICE_TYPE}: " --preview "echo {}" --query "${DB_NAME}")

    if [ $? -eq 0 ]; then
        echo "${CHOICE}"
    else
        echo ""
    fi
}

select_restore() {
    local DB_NAME=$1
    local CHOICE BACKUP_DIR BACKUP_BASE BACKUP_FILE LB_ID

    CHOICE=$(choice_backup "${DB_NAME}" "RESTORE")

    if [ -z "${CHOICE}" ]; then
        log WARN RESTORE: «CANCEL»
        exit 1
    fi

    BACKUP_DIR=$(echo "${CHOICE}" | awk '{print $1}')
    BACKUP_BASE=$(echo "${CHOICE}" | awk '{print $2}')
    BACKUP_FILE=${PSQL_ARCHIVE_DIR}/${BACKUP_DIR}/${BACKUP_BASE}

    if [ "${BACKUP_DIR}" == ".." ]; then
        log INFO RESTORE: ${BACKUP_DIR}
        select_action ${DB_NAME} ${LB_ID}
    else
        log INFO RESTORE: ${BACKUP_FILE}
        do_backup ${DB_NAME} r
        log WARN  ${BACKUP_FILE}
        do_restore ${DB_NAME} ${BACKUP_FILE}
        select_action ${DB_NAME} ${LB_ID}
    fi
}

select_upload() {
    local DB_NAME=$1 
    local CHOICE BACKUP_DIR BACKUP_BASE BACKUP_FILE LB_ID

    CHOICE=$(choice_backup "${DB_NAME}" "UPLOAD")

    if [ -z "${CHOICE}" ]; then
        log WARN UPLOAD: «CANCEL»
        exit 1
    fi

    BACKUP_DIR=$(echo "${CHOICE}" | awk '{print $1}')
    BACKUP_BASE=$(echo "${CHOICE}" | awk '{print $2}')
    BACKUP_FILE=${PSQL_ARCHIVE_DIR}/${BACKUP_DIR}/${BACKUP_BASE}

    if [ "${BACKUP_DIR}" == ".." ]; then
        log INFO UPLOAD: ${BACKUP_DIR}
        select_action ${DB_NAME} ${LB_ID}
    else
        log INFO UPLOAD: ${BACKUP_FILE}
        do_upload ${BACKUP_FILE}
        select_action ${DB_NAME} ${LB_ID}
    fi
}

do_restore(){
    local DB_NAME=$1
    local BACKUP_FILE=$2
    local BACKUP_TAR_GZ TEMP_DIR

    if [[ "${BACKUP_FILE}" == *.tar.gz ]]; then
        BACKUP_TAR_GZ=true
    else
        BACKUP_TAR_GZ=false
    fi
    
    if [ "${BACKUP_TAR_GZ}" = true ]; then
        TEMP_DIR=$(mktemp -d)
        log ERROR ${TEMP_DIR}
        tar -xzf "${BACKUP_FILE}" -C "${TEMP_DIR}"
        BACKUP_FILE=$(find "${TEMP_DIR}" -name "*.sql" -type f)
    fi

    log ERROR ${BACKUP_FILE}
    
    if [ -n "${BACKUP_FILE}" ]; then
        log DEBUG "Restoring from ${BACKUP_FILE}"
        do_wipeout ${DB_NAME}
        sed -E "s/( OWNER TO) [^;]+;$/\1 \"${DB_NAME}\";/" ${BACKUP_FILE} | psql -U ${DB_NAME} -h ${PSQL_HOST} -d ${DB_NAME}

        if [ $? -eq 0 ]; then
            log SUCCESS "Restore successful: ${DB_NAME}"
        else
            log ERROR "Restore failed: ${DB_NAME}"
        fi
        if [ "${BACKUP_TAR_GZ}" = true ]; then
            rm -rf "${TEMP_DIR}"
        fi
    else
        log WARN "No file selected."
    fi
}

do_wipeout(){
    local DB_NAME=$1

    psql -U ${PSQL_USER} -h ${PSQL_HOST} -d ${DB_NAME} << 'EOF'
DO $$ DECLARE
    t RECORD;
BEGIN
    FOR t IN (SELECT tablename FROM pg_tables WHERE schemaname = current_schema()) LOOP
        EXECUTE 'DROP TABLE ' || quote_ident(t.tablename) || ' CASCADE';
    END LOOP;
END $$;

DO $$ DECLARE
    s RECORD;
BEGIN
    FOR s IN (SELECT * FROM information_schema.sequences) LOOP
        EXECUTE 'DROP SEQUENCE ' || quote_ident(s.sequence_name);
    END LOOP;
END $$;

VACUUM FULL;
EOF
}

function do_upload() {
    if [[ -z "$1" ]]; then
        echo "Please specify a file as the first parameter."
        exit 1
    fi

    if [[ ! -z "$2" ]]; then
        SHARE_LINK_TTL="$2"
    fi

    curl -s "${SHARE_LINK_URL}/u?ttl=${SHARE_LINK_TTL}" -F "file=@$1" | jq
}

function install_if_missing() {
    apt update
    for PACKAGE in "$@"; do
        if ! command -v "${PACKAGE}" &> /dev/null; then
            echo "${PACKAGE} is not installed. Installing..."
            apt install -y "${PACKAGE}"
        else
            echo "${PACKAGE} is already installed."
        fi
    done
}


function psql_sentinel() {
    install_if_missing fzf curl jq

    if [[ $# -lt 2 ]]; then
        clear
    fi

    log HEAD "psql-sentinel @ ${PSQL_ARCHIVE_DIR} & ${PSQL_CACHE_FILE}"
    log INFO "[ ${AMS_NAME} | ${AMS_REVISION} | ${AMS_DEPLOY} | ${AMS_ENV} ]"

    if [[ $# -ge 2 ]]; then
        local db_name=$1
        local backup_type=$2
        log INFO "Parameters detected: database='${db_name}', backup_type='${backup_type}'"
        do_backup "${db_name}" "${backup_type}"
    else
        select_db
    fi
}

psql_sentinel "$@"

exit 0
EOS
chmod 755 ${SCRIPT_NAME}
${SCRIPT_NAME}