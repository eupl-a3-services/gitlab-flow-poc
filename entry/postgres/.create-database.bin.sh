#!/bin/bash
DATABASE="$1"
USER="${DATABASE}"

log DEBUG Creating database if not exists: ${DATABASE}
if [[ "$(psql -U "$POSTGRES_USER" -A -tc "SELECT 1 FROM pg_database WHERE datname = '${DATABASE}'")" == "1" ]]; then
	echo "Database ${DATABASE} already exists!"
else
	psql -U postgres -c "CREATE DATABASE \"${DATABASE}\" OWNER \"${USER}\""
fi