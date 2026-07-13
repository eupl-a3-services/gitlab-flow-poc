#!/bin/bash
# Easy Java Manager (Updated to match ENM dynamic versions)

set -e

EJM_DIR="/opt/ejm_versions"
CURRENT_JAVA_LINK="/usr/lib/jvm/current"
DEFAULT_JAVA_LINK="/usr/lib/jvm/default-jvm"

JAVA_VERSIONS_CACHE="/opt/.java_versions_cache"
JAVA_VERSIONS_CACHE_TTL=3600

ANSI_GREEN="\033[0;32m"
ANSI_ORANGE="\033[0;33m"
ANSI_GRAY="\033[1;30m"
ANSI_RESET="\033[0m"

format_version() {
  local name="$1"
  local size="$2"
  local state="$3"

  local prefix="${ANSI_GRAY}· ${ANSI_RESET}"
  local suffix=" ${ANSI_GRAY}[remote]${ANSI_RESET}"

  if [ "$state" = "installed" ]; then
    prefix="${ANSI_ORANGE}• ${ANSI_RESET}"
    suffix=" ${ANSI_ORANGE}[installed]${ANSI_RESET}"
  fi

  if [ "$state" = "active" ]; then
    prefix="${ANSI_GREEN}* ${ANSI_RESET}"
    suffix=" ${ANSI_GREEN}[active]${ANSI_RESET}"
  fi

  echo -e "${prefix}${name} (${size})${suffix}"
}

install_java() {
  local version=$1
  local url=""

  if [ -z "$version" ]; then
    log ERROR "Java version is required (e.g., 25, 21, or full tag like 25.0.3+9)."
    exit 1
  fi

  mkdir -p "${EJM_DIR}"
  cd "${EJM_DIR}" || exit 1

  if [ -d "${version}" ]; then
    log WARN "Java ${version} is already installed."
    return
  fi

  url="https://api.adoptium.net/v3/binary/version/jdk-$version/alpine-linux/x64/jdk/hotspot/normal/eclipse"
  
  log INFO "Downloading Java ${version} from source '${url}'."

  local archive="/tmp/java-${version}.tar.gz"
  
  # Pridané -f pre potlačenie HTTP chýb a -L pre správne presmerovanie (redirect)
  if ! curl -f -L -o "${archive}" "${url}"; then
    log ERROR "Failed to download Java ${version}. Check if the version is valid."
    exit 1
  fi

  log INFO "Extracting Java ${version}..."
  mkdir -p "${version}"
  tar -xzf "${archive}" --strip-components=1 -C "${version}"
  rm -f "${archive}"

  if [ ! -x "${version}/bin/java" ]; then
    log ERROR "Java binary not found: ${EJM_DIR}/${version}/bin/java"
    rm -rf "${version}"
    exit 1
  fi

  log INFO "Java ${version} installed."
  use_java "${version}"
}

use_java() {
  local java_version=$1
  local JAVA_DIR="${EJM_DIR}/${java_version}"

  if [ -z "$java_version" ]; then
    log ERROR "Java version is required."
    exit 1
  fi

  if [ ! -d "${JAVA_DIR}" ]; then
    log ERROR "Java version $java_version is not installed."
    exit 1
  fi

  if [ ! -x "${JAVA_DIR}/bin/java" ]; then
    log ERROR "Java binary not found in ${JAVA_DIR}/bin/java"
    exit 1
  fi

  mkdir -p "$(dirname "${CURRENT_JAVA_LINK}")"

  # Prelinkovanie hlavných adresárov prostredia
  ln -sfn "${JAVA_DIR}" "${CURRENT_JAVA_LINK}"
  ln -sfn "${JAVA_DIR}" "${DEFAULT_JAVA_LINK}"

  # Výmena symlinkov v /usr/bin pre globálnu dostupnosť
  ln -sfn "${CURRENT_JAVA_LINK}/bin/java" /usr/bin/java

  if [ -x "${CURRENT_JAVA_LINK}/bin/javac" ]; then
    ln -sfn "${CURRENT_JAVA_LINK}/bin/javac" /usr/bin/javac
  fi

  if [ -x "${CURRENT_JAVA_LINK}/bin/jar" ]; then
    ln -sfn "${CURRENT_JAVA_LINK}/bin/jar" /usr/bin/jar
  fi

  hash -r 2>/dev/null || true

  log INFO "Switched to Java ${java_version}"
  java -version 2>&1 | head -n 1
}

normalize_java_version() {
  echo "$1" | sed 's/ (LTS)$//'
}

list_versions() {
  local active_version=""
  local total_bytes=0

  if [ -L "${CURRENT_JAVA_LINK}" ]; then
    local java_link
    java_link=$(readlink "${CURRENT_JAVA_LINK}")
    active_version=$(basename "$java_link")
  fi

  if [ -d "${EJM_DIR}" ]; then
    for version_dir in "${EJM_DIR}"/*; do
      [ -d "$version_dir" ] || continue

      local version size_bytes size_hr state

      version=$(basename "$version_dir")

      size_bytes=$(du -sb "$version_dir" 2>/dev/null | awk '{print $1}')
      total_bytes=$((total_bytes + size_bytes))

      size_hr=$(numfmt --to=iec --suffix=B "$size_bytes" 2>/dev/null)

      state="installed"
      [ "$version" = "$active_version" ] && state="active"

      format_version "$version" "$size_hr" "$state"
    done

    local total_hr
    total_hr=$(numfmt --to=iec --suffix=B "$total_bytes" 2>/dev/null)

    echo ""
    echo -e "${ANSI_GREEN}Total installed size:${ANSI_RESET} ${total_hr}"
  fi
}

load_java_versions() {

  if [ -f "${JAVA_VERSIONS_CACHE}" ]; then

    local age
    age=$(( $(date +%s) - $(stat -c %Y "${JAVA_VERSIONS_CACHE}") ))

    if [ "$age" -lt "$JAVA_VERSIONS_CACHE_TTL" ]; then
      cat "${JAVA_VERSIONS_CACHE}"
      return 0
    fi
  fi

  mkdir -p "$(dirname "${JAVA_VERSIONS_CACHE}")"

  local versions

  versions=$(
    curl -fsSL "https://api.adoptium.net/v3/info/available_releases" \
    | jq -r '.available_releases[]' \
    | while read -r major; do
        curl -fsSL "https://api.adoptium.net/v3/assets/feature_releases/${major}/ga" \
        | jq -r '.[].version_data.openjdk_version'
      done \
    | sed 's/-LTS$/ (LTS)/' \
    | sort -Vu
  )

  if [ -z "$versions" ]; then
    return 1
  fi

  echo "$versions" > "${JAVA_VERSIONS_CACHE}"

  echo "$versions"
}

search_versions() {
  local search_term=$1

  if ! command -v jq >/dev/null 2>&1; then
    log ERROR "This command requires jq."
    exit 1
  fi

  log INFO "Fetching available Java versions from Adoptium..."

  local raw_versions
  raw_versions=$(load_java_versions)

  if [ $? -ne 0 ] || [ -z "$raw_versions" ]; then
    log ERROR "Failed to fetch versions from Adoptium."
    exit 1
  fi

  local filtered_versions

  if [ -n "$search_term" ]; then
    filtered_versions=$(echo "$raw_versions" | grep "^${search_term}" || true)

    if [ -z "$filtered_versions" ]; then
      log WARN "No online versions match '${search_term}'."
      return
    fi
  else
    filtered_versions=$(echo "$raw_versions" | sort -rV | head -n 50)
  fi

  # 👉 active java
  local active_java_real=""
  if [ -e "${CURRENT_JAVA_LINK}" ]; then
    active_java_real=$(readlink -f "${CURRENT_JAVA_LINK}" 2>/dev/null || true)
  fi

  # 👉 installed map
  declare -A installed_versions

  if [ -d "${EJM_DIR}" ]; then
    for dir in "${EJM_DIR}"/*; do
      [ -d "$dir" ] || continue
      installed_versions["$(basename "$dir")"]="$(readlink -f "$dir")"
    done
  fi

  echo "$filtered_versions" | sort -rV | while IFS= read -r version; do
    [ -n "$version" ] || continue

    local normalized
    normalized=$(normalize_java_version "$version")

    local state="remote"
    local size="-"

    # installed check
    if [[ -n "${installed_versions[$normalized]}" ]]; then
      state="installed"

      # active override
      if [[ "${installed_versions[$normalized]}" == "${active_java_real}" ]]; then
        state="active"
      fi

      # size len pre installed
      size=$(du -sh "${EJM_DIR}/${normalized}" 2>/dev/null | awk '{print $1}')
    fi

    format_version "$version" "$size" "$state"
  done
}

case "$1" in
  install)
    install_java "$2"
    ;;
  use)
    use_java "$2"
    ;;
  list)
    list_versions
    ;;
  search)
    search_versions "$2"
    ;;
  *)
    log USAGE "Easy Java Manager"
    log USAGE "Usage: $0 {install|use|list|search} [version]"
    exit 1
    ;;
esac
