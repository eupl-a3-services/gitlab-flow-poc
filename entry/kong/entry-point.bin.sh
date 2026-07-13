#!/bin/sh

set -eu

export AMS_RUN=$(date +"%y%m%d-%H%M%S")
echo -e "--🄰🄼🅂-- \\e[35m${AMS_RUN}\\e[0m --🄰🄼🅂--"

if [ "$#" -eq 0 ]; then
  /docker-entrypoint.sh kong docker-start
else
  /docker-entrypoint.sh "$@"
fi

