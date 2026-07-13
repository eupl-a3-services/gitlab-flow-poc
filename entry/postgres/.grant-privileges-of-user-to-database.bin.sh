#!/bin/bash
DATABASE="$1"
USER="$2"

log DEBUG Granting rights of database: ${DATABASE} to user ${USER}
psql -U "${POSTGRES_USER}" -tc "GRANT ALL PRIVILEGES ON DATABASE \"${DATABASE}\" TO \"${USER}\"";