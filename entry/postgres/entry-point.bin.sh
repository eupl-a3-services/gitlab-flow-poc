#!/bin/sh
#set -x
export AMS_RUN=$(date +"%y%m%d-%H%M%S")
echo -e "--🄰🄼🅂-- \\e[35m${AMS_RUN}\\e[0m --🄰🄼🅂--"

du -h ${ENTRY_VOLUME_DATA}

ams-service &
entry-init "Postgres" &

su - postgres -c "/usr/lib/postgresql/14/bin/pg_resetwal -f /var/lib/postgresql/data"
rm /var/lib/postgresql/data/postmaster.pid
/usr/local/bin/docker-entrypoint.sh "postgres"

log ERROR "FAILED !!!!!!!!!!!!!!!!"
sleep 600
