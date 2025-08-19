#!/bin/bash
#
# ansi-lint-env
#
# This script scans a file for environment variable placeholders (e.g. $VAR or ${VAR}),
# checks if these variables are set in the current environment,
# and prints them color-coded:
#   - Green: variable is set
#   - Red: variable is missing
#
# If any variable is missing, the script exits with status 1.
#
# Usage:
#   ansi-lint-env [file]
# If no file is specified, a default file path is used.
#
# Example:
#   ansi-lint-env myconfig.yml

ansi_lint_env() {
  local FILE="${1}"
  local HIDE_VALUES="${2:-false}"
  local left_text="$FILE"

  if [ "$HIDE_VALUES" = "true" ]; then
    left_text="*${left_text}*"
  fi

  if [ ! -f "$FILE" ]; then
    log ERROR "File '$FILE' does not exist."
    exit 1
  fi

  local VARS
  VARS=$(grep -oE '\$\{[a-zA-Z_][a-zA-Z0-9_]*\}|\$[a-zA-Z_][a-zA-Z0-9_]*' "$FILE" \
    | sed -E 's/^\$\{?([a-zA-Z_][a-zA-Z0-9_]*)\}?$/\1/' \
    | sort -u)

  local MISSING_COUNT=0

  ansi-bar LINT-ENV "${left_text}"

  for VAR in $VARS; do
    if [[ "$VAR" =~ ^[a-z_]+$ ]]; then
      printf "\033[1;34m%-50s\033[0m%s\n" "$VAR" "«ignore»"
      continue
    fi
    if [ -n "${!VAR+x}" ]; then
      local VALUE="${!VAR}"
      local DISPLAY_VALUE

      if [ "$HIDE_VALUES" = "true" ]; then
        local LEN=${#VALUE}
        if [ $LEN -le 4 ]; then
          DISPLAY_VALUE="${VALUE:0:1}***"
        else
          local FIRST_CHAR="${VALUE:0:1}"
          local LAST_CHARS="${VALUE: -3}"
          local STARS_COUNT=$((LEN - 4))
          local STARS=$(printf '%*s' "$STARS_COUNT" '' | tr ' ' '*')
          DISPLAY_VALUE="${FIRST_CHAR}${STARS}${LAST_CHARS}"
        fi
      else
        DISPLAY_VALUE="$VALUE"
      fi

      if [ -z "$VALUE" ]; then
        printf "\033[0;33m%-50s\033[0m%s\n" "$VAR" "«empty»"
      else
        printf "\033[0;32m%-50s\033[0m%s\n" "$VAR" "$DISPLAY_VALUE"
      fi
    else
      printf "\033[0;31m%s\033[0m\n" "$VAR"
      MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
  done

  local var_count=$(echo "$VARS" | wc -l)
  local right_text="vars: $var_count | missing: $MISSING_COUNT"

  ansi-bar LINT-ENV "${left_text}" "${right_text}"

  if [ "$MISSING_COUNT" -gt 0 ]; then
    log ERROR "At least one required environment variable is missing."
    exit 1
  fi
}

ansi_lint_env $1 $2