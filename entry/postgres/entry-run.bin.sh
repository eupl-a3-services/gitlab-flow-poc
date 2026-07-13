#!/bin/sh

#export PSQL_VOLUME_DATA=/var/lib/postgresql/data
#export PSQL_ARCHIVE_DIR=/var/lib/postgresql/.archive
#export PSQL_BACKUP_LIST=/var/lib/postgresql/.psql-backup.list
#export AMS_LOG_DIR=/var/lib/postgresql/.log

ln -sf ${PSQL_VOLUME_DATA} .data
ln -sf ${PSQL_ARCHIVE_DIR} .archive
ln -sf ${PSQL_BACKUP_LIST} .psql-backup.list
ln -sf ${AMS_LOG_DIR} .log

chmod +x ams-service 2>/dev/null || true
chmod +x .*.bin.sh 2>/dev/null || true
chmod +x *.bin.sh 2>/dev/null || true

ln -sf "$(pwd)/ams-service" /usr/local/bin/ams-service

for script in .*.bin.sh *.bin.sh; do
     [ -e "$script" ] || continue
    ln -sf "$(pwd)/$script" "/usr/local/bin/$(basename "$script" .bin.sh)";
done

echo 'psql-list() { psql -h localhost -U postgres -c "\\l"; }' >> ~/.bashrc

