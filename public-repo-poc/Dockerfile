FROM alpine
  
ARG AMS AMS_HUB_NAME AMS_HUB_REVISION AMS_HUB_BUILD

RUN apk --no-cache add bash curl jq docker-cli tzdata git kubectl envsubst yq highlight openjdk11-jre \
    && mkdir -p /usr/local/lib/docker/cli-plugins/ \
    && curl -L https://github.com/docker/buildx/releases/download/v0.17.1/buildx-v0.17.1.linux-amd64 -o /usr/local/lib/docker/cli-plugins/docker-buildx \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

ENV AMS=${AMS} \
    AMS_HUB_NAME=${AMS_HUB_NAME} \
    AMS_HUB_REVISION=${AMS_HUB_REVISION} \
    AMS_HUB_BUILD=${AMS_HUB_BUILD} \
    TZ=Europe/Bratislava \
    DOCKER_BUILDKIT=1

WORKDIR /opt/${AMS_HUB_NAME}

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