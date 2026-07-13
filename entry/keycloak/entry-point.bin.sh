#!/bin/sh
#set -x
export AMS_RUN=$(date +"%y%m%d-%H%M%S")
echo -e "--🄰🄼🅂-- \\e[35m${AMS_RUN}\\e[0m --🄰🄼🅂--"

ams-service &
entry-init "Keycloak" &
/opt/keycloak/bin/kc.sh "start"

log ERROR "FAILED !!!!!!!!!!!!!!!!"
sleep 600
