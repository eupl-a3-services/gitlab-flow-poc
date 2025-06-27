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
  version=$1
  if [ ! -d "${ENM_DIR}/${version}" ]; then
    log ERROR "Node version $version is not installed."
    exit 1
  fi

  ln -sf "${ENM_DIR}/${version}/bin/node" /usr/local/bin/node
  ln -sf "${ENM_DIR}/${version}/bin/npm" /usr/local/bin/npm
  
  log INFO "Switched to Node ${version}"
  node -v
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
  list)
    list_versions
    ;;
  *)
    log USAGE "Usage: $0 {install|use|list} [version]"
    ;;
esac
