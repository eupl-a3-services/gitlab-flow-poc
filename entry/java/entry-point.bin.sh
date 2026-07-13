#!/bin/sh

export AMS_RUN=$(date +"%y%m%d-%H%M%S")
echo -e "--🄰🄼🅂-- \e[35m${AMS_RUN} (hold $AMS_HOLD)\e[0m --🄰🄼🅂--"

export AMS_ENV=${AMS_SPACE}
cd /opt/springboot
java -jar springboot-${AMS_NAME}.jar 2>&1
EXIT_CODE=$?

echo -e "--🄰🄼🅂-- \e[31m!!! FAILED (exit $EXIT_CODE) !!!\e[0m --🄰🄼🅂--"
if [ "${AMS_HOLD}" = "true" ] && [ "$EXIT" -ne 0 ]; then
  sleep 60
fi
exit $EXIT_CODE