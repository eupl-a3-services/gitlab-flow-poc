#!/bin/bash
# Easy Maven Manager

set -e

EMM_DIR="/opt/emm_versions"

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

install_maven() {
  version=$1

  mkdir -p "$EMM_DIR"
  cd "$EMM_DIR" || exit 1

  if [ -d "$version" ]; then
    log WARN "Maven ${version} is already installed."
    return
  fi

  url="https://archive.apache.org/dist/maven/maven-3/${version}/binaries/apache-maven-${version}-bin.tar.gz"

  log INFO "Downloading Maven ${version} from source '${url}'."

  filename=$(basename "$url")
  dirname="apache-maven-${version}"

  curl -fL -o "$filename" "$url"

  log INFO "Extracting..."
  tar -xzf "$filename"

  mv "$dirname" "$version"
  rm "$filename"

  log INFO "Maven ${version} installed."
  use_maven "$version"
}

use_maven() {
  version=$1
  MVN_DIR="${EMM_DIR}/${version}"

  if [ ! -d "$MVN_DIR" ]; then
    log ERROR "Maven version $version is not installed."
    exit 1
  fi

  # remove old symlink (safe)
  rm -f /usr/local/bin/mvn

  # IMPORTANT: link whole bin dir behavior via MAVEN_HOME
  export MAVEN_HOME="$MVN_DIR"
  export PATH="$MAVEN_HOME/bin:$PATH"

  # optional global symlink (works but not required)
  ln -sf "$MVN_DIR/bin/mvn" /usr/local/bin/mvn

  log INFO "Switched to Maven ${version}"

  # verify
  mvn -v
}

list_versions() {
  local active_version=""
  local total_bytes=0

  if [ -L "/usr/local/bin/mvn" ]; then
    target=$(readlink "/usr/local/bin/mvn")
    active_version=$(echo "$target" | sed -E "s|^${EMM_DIR}/([^/]+)/.*|\1|")
  fi

  if [ -d "${EMM_DIR}" ]; then
    for dir in "$EMM_DIR"/*; do
      [ -d "$dir" ] || continue

      local version size_bytes size_hr state

      version=$(basename "$dir")

      size_bytes=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
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

search_versions() {
  local term=$1
  local url="https://archive.apache.org/dist/maven/maven-3/"

  log INFO "Fetching available Maven versions..."

  local versions
  versions=$(curl -s "$url" | grep -oE '3\.[0-9]+\.[0-9]+' | sort -V | uniq)

  if [ -n "$term" ]; then
    versions=$(echo "$versions" | grep "$term" || true)
  fi

  if [ -z "$versions" ]; then
    log WARN "No Maven versions found for '$term'"
    return
  fi

  for v in $versions; do
    local state="remote"
    local size=""

    if [ -d "${EMM_DIR}/${v}" ]; then
      state="installed"
      size=$(du -sh "${EMM_DIR}/${v}" 2>/dev/null | awk '{print $1}')
    fi

    format_version "$v" "${size:-"-"}" "$state"
  done
}

case "$1" in
  install)
    install_maven "$2"
    ;;
  use)
    use_maven "$2"
    ;;
  list)
    list_versions
    ;;
  search)
    search_versions "$2"
    ;;
  *)
    echo "Usage: $0 {install|use|list|remove} [version]"
    ;;
esac