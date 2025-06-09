#!/bin/bash

# env2dir <ENV_VAR_NAME>
# Extracts a base64 url-safe encoded tar.xz archive stored in environment variable ENV_VAR_NAME
# and restores its content to the current directory.
_env2dir() {
  local varname="$1"
 
  assert ENV ${varname}

  local encoded="${!varname}"
  local padding=$(( (4 - ${#encoded} % 4) % 4 ))
  local pad=$(printf '=%.0s' $(seq 1 $padding))

  echo "${encoded}${pad}" | tr '_-' '/+' | base64 -d > .env2dir.tar.xz || {
    log ERROR "Failed to decode base64 data from variable '$varname'."
    return 1
  }

  tar -xJf .env2dir.tar.xz || {
    log ERROR "Failed to extract archive '.env2dir.tar.xz'."
    rm -f .env2dir.tar.xz
    return 2
  }

  rm -f .env2dir.tar.xz
}

if [[ $# -ne 1 ]]; then
    log USAGE "$0 <ENV_VAR_NAME>"
    exit 64
fi

_env2dir "$1"