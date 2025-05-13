#!/bin/bash
#run on root@chzb-vm

REGISTRATION_TOKEN=glrt-*****
RUNNER_NAME='chzb-runner'
RUNNER_TAGS='chzb'
RUNNER_URL='https://gitlab.com/'

gitlab-runner unregister --name ${RUNNER_NAME}

gitlab-runner register \
 --url ${RUNNER_URL} \
 --registration-token "${REGISTRATION_TOKEN}" \
 --description "${RUNNER_NAME}" \
 --tag-list "${RUNNER_TAGS}" \
 --custom_build_dir-enabled=true \
 --executor docker \
 --docker-image alpine \
 --docker-volumes "/var/run/docker.sock:/var/run/docker.sock" \
 --docker-volumes "/cache-volume:/cache-volume:rw" \
 --cache-dir "/cache-dir" \
 --docker-cache-dir "/cache-docker" \
 --docker-tmpfs "/ramdisk:rw,exec" \
 --non-interactive \
 --docker-pull-policy "if-not-present" \
 --docker-pull-policy "always"