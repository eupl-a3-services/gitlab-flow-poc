#!/bin/bash
#SCRIPT_NAME=/usr/local/bin/psql-init; cat <<"EOS" > ${SCRIPT_NAME}

#set -Eeo pipefail

emptyBackupFile() {
  > "$PSQL_BACKUP_LIST"
  log DEBUG "Backup list file has been emptied."
}

backupDatabase() {
	DATABASE="$1"

	log DEBUG Adding database to backup list: ${DATABASE}
	echo "${DATABASE}" >> "$PSQL_BACKUP_LIST"
}

createDatabase() {
	DATABASE="$1"
  USER="${DATABASE}"

	log DEBUG Creating database if not exists: ${DATABASE}
	if [[ "$(psql -U "$POSTGRES_USER" -A -tc "SELECT 1 FROM pg_database WHERE datname = '${DATABASE}'")" == "1" ]]; then
		echo "Database ${DATABASE} already exists!"
	else
		psql -U postgres -c "CREATE DATABASE \"${DATABASE}\" OWNER \"${USER}\""
	fi
}

createUser() {
	USER="$1"
	PASSWORD="$2"

	log DEBUG Creating user if not exists: ${USER}
	psql -U "${POSTGRES_USER}" --no-psqlrc --single-transaction --pset=pager=off \
	  --tuples-only \
	  --set=ON_ERROR_STOP=1 \
	  --set=vUsername=${USER} \
	  --set=vPassword=${PASSWORD} << 'EOF'
CREATE OR REPLACE FUNCTION pg_temp.create_user_if_not_exists(theUsername text, thePassword text)
RETURNS void AS
$BODY$
DECLARE
  duplicate_object_message text;
BEGIN
  BEGIN
    EXECUTE format(
      'CREATE USER %I WITH PASSWORD %L',
      theUsername,
      thePassword
    );
  EXCEPTION WHEN duplicate_object THEN
    GET STACKED DIAGNOSTICS duplicate_object_message = MESSAGE_TEXT;
    RAISE NOTICE '%, skipping', duplicate_object_message;
  END;
END;
$BODY$
LANGUAGE 'plpgsql';

SELECT pg_temp.create_user_if_not_exists(:'vUsername', :'vPassword');
EOF
}

grantPrivilegesOfUserToDatabase() {
	DATABASE="$1"
	USER="$2"

	log DEBUG Granting rights of database: ${DATABASE} to user ${USER}
	psql -U "${POSTGRES_USER}" -tc "GRANT ALL PRIVILEGES ON DATABASE \"${DATABASE}\" TO \"${USER}\"";
}

createUnaccentFunction() {
    DATABASE="$1"
    USER="$2"
    
    #log INFO "Skipping the creation of the unaccent function."
    #return 0

    log DEBUG Creating unaccent extension and function in database: ${DATABASE}
    psql -U postgres ${DATABASE} << 'EOF'
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE OR REPLACE FUNCTION public.immutable_unaccent(regdictionary, text)
  RETURNS text LANGUAGE c IMMUTABLE STRICT AS
'$libdir/unaccent', 'unaccent_dict';
EOF
    psql -U ${USER} ${DATABASE} << 'EOF'
CREATE OR REPLACE FUNCTION public.f_unaccent(text)
  RETURNS text LANGUAGE sql IMMUTABLE STRICT AS
$func$
SELECT public.immutable_unaccent(regdictionary 'public.unaccent', $1)
$func$;
EOF
}

_wipe_data() {
    log INFO "Initiating the removal of the entire PostgreSQL data directory at ${PSQL_VOLUME_DATA}..."
    rm -rf ${PSQL_VOLUME_DATA}
    log INFO "Successfully deleted the PostgreSQL data directory at ${PSQL_VOLUME_DATA}"
}

_main() {
    log HEAD $0

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --wipe-data) _wipe_data; exit 0 ;;
            *) echo "Unknown parameter: $1" ;;
        esac
        shift
    done

    du -h ${PSQL_VOLUME_DATA}

    if [ -z "${AMS_SPACE}" ]; then
        log ERROR 'Environment variable AMS_SPACE is not set.'
        exit 1
    fi

    PSQL_INIT_LIMIT=30
    PSQL_INIT_COUNT=0

    log INFO "waiting for pg_isready, limit: ${PSQL_INIT_LIMIT}"
    while ! pg_isready -t 2 -U postgres > /dev/null 2>&1; do
        (( PSQL_INIT_COUNT ++))

        log WARN ${PSQL_INIT_COUNT}/${PSQL_INIT_LIMIT}: PSQL is not ready yet. Waiting for 5 seconds before retrying.

        if (( ${PSQL_INIT_COUNT} >= ${PSQL_INIT_LIMIT} )); then
        log ERROR Postgres is not ready after ${PSQL_INIT_LIMIT} attempts
        exit 1
        fi

        sleep 5
    done

    log INFO "Postgres became ready (after ${PSQL_INIT_COUNT} attempts)"


    SCRIPT_BASE="$(dirname "$(readlink -f "$0")")"

    PSQL_INIT_DIR=${PSQL_INIT_DIR}/${AMS_SPACE}

    if [ -d "${PSQL_INIT_DIR}" ]; then
        source ${SCRIPT_BASE}/create.sh

        pushd ${PSQL_INIT_DIR}
        PSQL_INIT_COUNT=0
        for PSQL_INIT_FILE in *.sh; do
            (( PSQL_INIT_COUNT++ ))

            log INFO Executing script [${PSQL_INIT_COUNT}]: ${PSQL_INIT_FILE}
            source "${PSQL_INIT_FILE}"
        done
        popd
    else
        log ERROR PSQL_INIT_DIR not found: ${PSQL_INIT_DIR}
    fi

    log SUCCESS "$0: execution of all initdb scripts (${PSQL_INIT_COUNT}): FINISHED SUCCESSFULLY"
}

_main "$@"

exit 0
EOS
chmod 755 ${SCRIPT_NAME}