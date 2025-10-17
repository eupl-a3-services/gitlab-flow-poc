#!/bin/bash
# Easy Node Manager

set -e

ENM_DIR="/opt/enm_versions"

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
  ls "${ENM_DIR}"
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
  *)
    log USAGE "Usage: $0 {install|use|list} [version]"
    ;;
esac
