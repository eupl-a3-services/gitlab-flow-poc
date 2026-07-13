#!/bin/bash
# Easy Node Manager

set -e

ENM_DIR="/opt/enm_versions"

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

install_node() {
  version=$1
  mkdir -p "${ENM_DIR}"
  cd "${ENM_DIR}" || exit 1
  
  if [ -d "${version}" ]; then
    log WARN "Node ${version} is already installed."
    return
  fi

  url="https://unofficial-builds.nodejs.org/download/release/v$version/node-v$version-linux-x64-musl.tar.xz"
  #url="https://nodejs.org/dist/v$version/node-v$version-linux-x64.tar.xz"
  
  log INFO "Downloading Node.js ${version} from source '${url}'."

  basename=$(basename "${url}")
  dirname="${basename%.tar.xz}"

  curl -O ${url}
  
  log INFO "Extracting..."
  tar -xf "${basename}"
  mv "${dirname}" "${version}"
  rm ${basename}
  
  log INFO "Node ${version} installed."
  use_node ${version}
}

use_node() {
  node_version=$1
  NODE_DIR="${ENM_DIR}/${node_version}"

  if [ ! -d "$NODE_DIR" ]; then
    log ERROR "Node version $node_version is not installed."
    exit 1
  fi

  # delete old simlink
  for bin in /usr/local/bin/*; do
    if [ -L "$bin" ] && readlink "$bin" | grep -q "^$ENM_DIR"; then
      rm "$bin"
    fi
  done

  # create new simlink
  for bin in "$NODE_DIR/bin/"*; do
    ln -sf "$bin" /usr/local/bin/$(basename "$bin")
  done

  log INFO "Switched to Node ${node_version}"
  node -v
}

use_yarn() {
  yarn_version=$1
  if ! command -v corepack &> /dev/null; then
    log ERROR "Corepack is not installed."
    exit 1
  fi

  corepack enable
  corepack prepare yarn@"$yarn_version" --activate

  log INFO "Switched to Yarn ${yarn_version}"
  yarn -v
}

list_versions() {
  local active_version=""
  local total_bytes=0

  if [ -L "/usr/local/bin/node" ]; then
    local node_link
    node_link=$(readlink "/usr/local/bin/node")
    active_version=$(echo "$node_link" | sed -E "s|^${ENM_DIR}/([^/]+)/.*|\1|")
  fi

  if [ -d "${ENM_DIR}" ]; then
    for version_dir in "${ENM_DIR}"/*; do
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

search_versions() {
  local search_term=$1
  local index_url="https://nodejs.org/dist/index.tab"

  if ! command -v awk &> /dev/null; then
    log ERROR "This command requires 'awk' to parse the list."
    exit 1
  fi

  local active_version=""
  if [ -L "/usr/local/bin/node" ]; then
    local node_link
    node_link=$(readlink "/usr/local/bin/node")
    active_version=$(echo "$node_link" | sed -E "s|^${ENM_DIR}/([^/]+)/.*|\1|")
  fi

  log INFO "Fetching available Node.js (musl) versions online..."

  local raw_versions
  raw_versions=$(curl -s "$index_url" | awk 'NR>1 {
    version = $1;
    lts = $10;
    if (lts != "-") {
      print version " (LTS: " lts ")"
    } else {
      print version
    }
  }' | sed 's/^v//')

  local filtered_versions
  if [ -n "$search_term" ]; then
    filtered_versions=$(echo "$raw_versions" | grep "^$search_term" || true)
    if [ -z "$filtered_versions" ]; then
      log WARN "No online versions match '$search_term'."
      return
    fi
  else
    filtered_versions=$(echo "$raw_versions" | head -n 200)
  fi

  echo "$filtered_versions" | while IFS= read -r line; do
    local v_clean
    v_clean=$(echo "$line" | awk '{print $1}')

    local size=""
    local state="remote"

    if [ -d "${ENM_DIR}/${v_clean}" ]; then
      state="installed"

      # size len ak existuje lokálne
      size=$(du -sh "${ENM_DIR}/${v_clean}" 2>/dev/null | awk '{print $1}')
    fi

    # ak je aktívna verzia
    if [ "$v_clean" = "$active_version" ]; then
      state="active"
      size=$(du -sh "${ENM_DIR}/${v_clean}" 2>/dev/null | awk '{print $1}')
    fi

    # fallback size pre remote
    [ -z "$size" ] && size="-"

    format_version "$v_clean" "$size" "$state"
  done
}

case "$1" in
  install)
    install_node "$2"
    ;;
  use)
    use_node "$2"
    ;;
  yarn)
    use_yarn "$2"
    ;;
  list)
    list_versions
    ;;
  search)
    search_versions "$2"
    ;;
  *)
    log USAGE "Easy Node Manager"
    log USAGE "Usage: $0 {install|use|list|search} [version]"
    ;;
esac
