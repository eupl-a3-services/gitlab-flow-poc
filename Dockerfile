FROM alpine:3.21.3

ARG AMS AMS_NAME AMS_REVISION AMS_BUILD

ENV AMS=${AMS} \
    AHS_NAME=${AMS_NAME} \
    AHS_REVISION=${AMS_REVISION} \
    AHS_BUILD=${AMS_BUILD} \
    TZ=Europe/Bratislava \
    PS1="\[\e[1;35m\]\u\[\e[1;34m\]@\[\e[1;32m\]\${AHS_NAME}\[\e[1;34m\]:\[\e[1;33m\]\${AHS_REVISION}\[\e[1;34m\]:\[\e[1;36m\]\w \[\e[1;35m\]\\$\[\e[0m\] " \
    SHELL=/bin/bash \
    TERM=xterm \
    DOCKER_BUILDKIT=1\
    PATH="/opt/gitlab-flow/bin:${PATH}"\
    GLF_VERSION="/cache-volume/.glf.version"\
    AUTH_HTPASSWD="/cache-volume/.auth.htpasswd"\
    ROLLOUT_HOME=/cache-volume/rolout\
    KUBECONFIG_HOME=/cache-volume/kubeconfig\
    ENV_HOME=/cache-volume/env\
    CI_HOME=/cache-volume/ci


WORKDIR /opt/${AMS_NAME}

COPY opt/ .

RUN apk upgrade && \
    apk --no-cache add bash curl jq docker-cli tzdata git kubectl envsubst yq highlight openjdk11-jre xz git-crypt gnupg unzip zip mc apache2-utils python3 autoconf automake libtool build-base nasm make gawk zlib-dev && \
    mkdir -p /usr/local/lib/docker/cli-plugins/ && \
    curl -L https://github.com/docker/buildx/releases/download/v0.22.0/buildx-v0.22.0.linux-amd64 -o /usr/local/lib/docker/cli-plugins/docker-buildx && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx && \
    adduser -D a3user && \
    addgroup -g 114 docker && \
    addgroup a3user docker && \
    chmod +x ./bin/* && \
    for file in ./bin/*.bin.sh; do mv "$file" "${file%.bin.sh}"; done && \
    curl -sL https://sentry.io/get-cli/ | sh && \
    enm install 16.13.2

#SHELL ["/bin/bash", "-c"]

#RUN npm install -g n
#RUN n 16.13.2

#RUN export HOME="/root" && \
#    export NVM_DIR="/root/.nvm" && \
#    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
#    . /root/.nvm/nvm.sh && \
#    echo ok
##RUN . /root/.nvm/nvm.sh && nvm install 16.13.2
#RUN log INFO cool
#RUN . /root/.nvm/nvm.sh && nvm >> /root/nvm 2>&1 || true
#RUN . /root/.nvm/nvm.sh && nvm install 16.13.2 >> /root/nvm.install 2>&1 || true
#    nvm install 16.13.2 && \
#    nvm alias default 16.13.2 && \
#    nvm use default && \
#    node -v

#        export NVM_DIR="$HOME/.nvm" && \
#    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && \

#    export NVM_DIR="$HOME/.nvm" && \
#    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && \
    #    echo 'export NVM_DIR="$HOME/.nvm"' >> /etc/profile.d/nvm.sh && \
#    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /etc/profile.d/nvm.sh

    #    chmod 775 ./dist/* && \
    #echo 'export PATH="/opt/gitlab-flow:$PATH"' >> /etc/profile.d/gitlab-flow.sh && \
    #chmod +x /etc/profile.d/gitlab-flow.sh
    #for BIN  in ./bin/*.bin.sh; do ln -s "$(pwd)/${BIN}" "/usr/local/bin/$(basename  "${BIN}" .bin.sh)"; done && \
    #for DIST in ./dist/*;       do ln -s "$(pwd)/${DIST}" "/usr/local/bin/$(basename "${DIST}"       )"; done

#USER a3user

LABEL org.opencontainers.image.title="hub-gitlab-flow"
LABEL org.opencontainers.image.description="This Docker image simplifies and streamlines the process of building, packaging, and deploying applications stored in a GitLab repository. It supports AMS attributes setup, artifact building, Docker image packaging, image validation, and deployment to Kubernetes-based application servers. It is designed to enhance the software development lifecycle by improving automation and consistency across projects."
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.url="https://hub.docker.com/r/a3services/hub-gitlab-flow"
LABEL org.opencontainers.image.source="https://github.com/eupl-a3-services/gitlab-flow-poc"
LABEL org.opencontainers.image.documentation="https://github.com/eupl-a3-services/gitlab-flow-poc"
LABEL org.opencontainers.image.licenses="EUPL-1.2"
LABEL org.opencontainers.image.vendor="WILLING + HEAR s.r.o."
LABEL org.opencontainers.image.authors="info@chzb.sk"
LABEL org.opencontainers.image.ref.name="hub-gitlab-flow:latest"
LABEL org.opencontainers.image.revision="git-commit-sha"
LABEL org.opencontainers.image.created="2025-03-30T12:00:00Z"
