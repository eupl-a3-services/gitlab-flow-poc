#!/bin/bash
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