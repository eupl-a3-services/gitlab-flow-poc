#!/bin/sh

BIN_DIR="/usr/local/bin"

BUILDX_URL="https://github.com/docker/buildx/releases/download/v0.22.0/buildx-v0.22.0.linux-amd64"
TRIVY_URL="https://github.com/aquasecurity/trivy/releases/download/v0.69.2/trivy_0.69.2_Linux-64bit.tar.gz"
HELM_URL="https://get.helm.sh/helm-v3.14.4-linux-amd64.tar.gz"
SENTRY_URL="https://sentry.io"

debug_info() {
  pwd
  ls -la
  ls -la bin 
}

setup_bin(){
    sh bin/.bin.bin.sh
    log INFO SUPEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEER!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
}

install_system_packages() {
  apk upgrade
  apk --no-cache add bash maven gcompat curl jq docker-cli tzdata git kubectl \
    envsubst yq highlight xz git-crypt gnupg unzip zip mc apache2-utils \
    python3 autoconf automake libtool build-base nasm make gawk zlib-dev coreutils
}

install_docker_buildx() {
  BUILDX_DIR="${BIN_DIR%/bin}/lib/docker/cli-plugins"
  mkdir -p "${BUILDX_DIR}"
  curl -L "$BUILDX_URL" -o "${BUILDX_DIR}/docker-buildx"
  chmod +x "${BUILDX_DIR}/docker-buildx"
}

install_trivy() {
  curl -L "$TRIVY_URL" -o trivy.tar.gz
  tar -xzf trivy.tar.gz
  mv trivy "${BIN_DIR}/trivy"
  chmod +x "${BIN_DIR}/trivy"
  rm -f trivy.tar.gz
}

install_helm() {
  curl -L "{$HELM_URL}" -o helm.tar.gz
  tar -xzf helm.tar.gz
  mv linux-amd64/helm "${BIN_DIR}/helm"
  chmod +x "${BIN_DIR}/helm"
  rm -f helm.tar.gz
}

setup_users_and_groups() {
  adduser -D a3user
  addgroup -g 114 docker
  addgroup a3user docker
}

install_sentry() {
  curl -sL "${SENTRY_URL}" | sh
}

install_easy_node_manager() {
  enm install 16.13.2
  enm install 22.12.0
  enm install 24.14.0
}

install_easy_java_manager() {
  ejm install 11.0.31+11
#  ejm install 17.0.19+10
  ejm install 21.0.10+7
  ejm install 25.0.3+9
}

install_easy_maven_manager() {
  emm install 3.6.3
}

main() {
    debug_info
    setup_bin
 
    install_system_packages
 
    install_docker_buildx
    install_trivy
    install_helm
    install_sentry
    install_easy_node_manager
    install_easy_java_manager
    install_easy_maven_manager
#    setup_users_and_groups

}

main

du -h -d 2