#!/bin/bash

set -e

#AMS_REVISION="1.8.2-79-g2aa941b4"
#AMS_NAME="is-ui"
#AMS_DEPLOY="240930-104723"
#AMS_ENV="fe-1"
#AMS_AREA=${AMS_ENV}
#AMS_DOMAIN=a3serices.dev

ping_loop() {
  local RETRIES=60
  local SLEEP_TIME=5

  for ((i=1; i<=${RETRIES}; i++)); do
    log INFO "Check ${i}/${RETRIES}: [sleep 5 sec...] -> ${AMS_ENDPOINT}"
    sleep "${SLEEP_TIME}"

    if check_deployment; then
      exit 0
    fi

    if [ "${i}" -eq "${RETRIES}" ]; then
      log ERROR "Deployment failed."
      exit 1
    fi
  done
}

compare_values() {
  local NAME="$1"
  local AMS="$2"
  local RESPONSE="$3"
  local RED="\033[0;31m"
  local GREEN="\033[0;32m"
  local NC="\033[0m"
  
  NAME=$(printf "%-17s" "$NAME")
  AMS=$(printf "%-22s" "$AMS")
  RESPONSE=$(printf "%-22s" "$RESPONSE")
  
  if [[ "$AMS" == "${RESPONSE}" ]]; then
    echo -e "| ${NAME} | ${GREEN}${AMS}${NC} | ${GREEN}${RESPONSE}${NC} | ${GREEN}Match   ${NC} |"
  else
    echo -e "| ${NAME} | ${RED}${AMS}${NC} | ${RED}${RESPONSE}${NC} | ${RED}No Match${NC} |"
  fi
}
check_deployment() {
  RESPONSE=$(curl -sk -w "%{http_code}" -o response.txt "${AMS_ENDPOINT}")
  HTTP_CODE="${RESPONSE:(-3)}"
  if [ -f response.txt ]; then
      BODY=$(<response.txt)
  fi

  if [[ "${HTTP_CODE}" -ne 200 ]]; then
    log WARN "Received HTTP response code ${HTTP_CODE} - ${BODY}"
    return 1
  fi

  RESPONSE_NAME=$(echo "${BODY}"          | grep -o '<text id="name"[^>]*>[^<]*'      | sed 's/.*>\([^<]*\).*/\1/')
  RESPONSE_DEPLOY=$(echo "${BODY}"        | grep -o '<text id="deploy"[^>]*>[^<]*'    | sed 's/.*>\([^<]*\).*/\1/')
  RESPONSE_ENV=$(echo "${BODY}"           | grep -o '<text id="env"[^>]*>[^<]*'       | sed 's/.*>\([^<]*\).*/\1/')
  RESPONSE_REVISION=$(echo "${BODY}"      | grep -o '<text id="revision"[^>]*>[^<]*'  | sed 's/.*>\([^<]*\).*/\1/')

  RESPONSE_HUB_REVISION=$(echo "${BODY}"  | grep -o '<text id="hub"[^>]*>[^<]*'       | sed 's/.*>\([^<]*\).*/\1/')
  RESPONSE_BUILD=$(echo "${BODY}"         | grep -o '<text id="build"[^>]*>[^<]*'     | sed 's/.*>\([^<]*\).*/\1/')
  RESPONSE_RELEASE=$(echo "${BODY}"       | grep -o '<text id="release"[^>]*>[^<]*'   | sed 's/.*>\([^<]*\).*/\1/')
  RESPONSE_RUN=$(echo "${BODY}"           | grep -o '<text id="run"[^>]*>[^<]*'       | sed 's/.*>\([^<]*\).*/\1/')

  echo "+-------------------+---------local----------+--------response--------+----------+"
  compare_values "AMS_NAME"         "${AMS_NAME}"         "${RESPONSE_NAME}"
  compare_values "AMS_REVISION"     "${AMS_REVISION}"     "${RESPONSE_REVISION}"
  compare_values "AMS_DEPLOY"       "${AMS_DEPLOY}"       "${RESPONSE_DEPLOY}"
  compare_values "AMS_RELEASE"      "${AMS_RELEASE}"      "${RESPONSE_RELEASE}"
  compare_values "AMS_ENV"          "${AMS_ENV}"          "${RESPONSE_ENV}"
  echo "+-------------------+------------------------+------------------------+----------+"
  compare_values "AMS_HUB_REVISION" "${AMS_HUB_REVISION}" "${RESPONSE_HUB_REVISION}"
  compare_values "AMS_BUILD"        "${AMS_BUILD}"        "${RESPONSE_BUILD}"
  compare_values "AMS_RUN"          "${AMS_RUN}"          "${RESPONSE_RUN}"
  echo "+-------------------+------------------------+------------------------+----------+"
  
  if [[ "${RESPONSE_REVISION}" == "${AMS_REVISION}" && \
        "${RESPONSE_NAME}" == "${AMS_NAME}" && \
        "${RESPONSE_DEPLOY}" == "${AMS_DEPLOY}" && \
        "${RESPONSE_ENV}" == "${AMS_ENV}" ]]; then
    log SUCCESS "Deployment successful."
    exit 0
  else
    return 1
  fi
}

ctx AMS_PING
ping_loop
