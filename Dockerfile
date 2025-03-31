FROM alpine:3.21.3

ARG AMS AMS_HUB_NAME AMS_HUB_REVISION AMS_HUB_BUILD

ENV AMS=${AMS} \
    AMS_HUB_NAME=${AMS_HUB_NAME} \
    AMS_HUB_REVISION=${AMS_HUB_REVISION} \
    AMS_HUB_BUILD=${AMS_HUB_BUILD} \
    TZ=Europe/Bratislava \
    DOCKER_BUILDKIT=1

WORKDIR /opt/${AMS_HUB_NAME}

RUN apk upgrade && \
    apk --no-cache add bash curl jq docker-cli tzdata git kubectl envsubst yq highlight openjdk11-jre && \
    mkdir -p /usr/local/lib/docker/cli-plugins/ && \
    curl -L https://github.com/docker/buildx/releases/download/v0.22.0/buildx-v0.22.0.linux-amd64 -o /usr/local/lib/docker/cli-plugins/docker-buildx && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx && \
    adduser -D a3user

COPY bin/ ./bin
COPY dist/ ./dist

RUN chmod 775 ./bin/* && \
    chmod 775 ./dist/* && \
    for BIN in ./bin/*.bin.sh; do \
        ln -s "$(pwd)/${BIN}" "/usr/local/bin/$(basename "${BIN}" .bin.sh)"; \
    done && \
    for DIST in ./dist/*; do \
        ln -s "$(pwd)/${DIST}" "/usr/local/bin/$(basename "${DIST}")"; \
    done

USER a3user

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
