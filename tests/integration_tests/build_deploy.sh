#!/bin/bash

set -exv

# We need to find absolute path since CI is running the script from repo's root directory.
ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE="quay.io/app-sre/rhobs-e2e"
IMAGE_TAG=$(git rev-parse --short=7 HEAD)

docker build -t "${IMAGE}:${IMAGE_TAG}" -f "${ABSOLUTE_PATH}/Dockerfile" .

if [[ -n "$QUAY_USER" && -n "$QUAY_TOKEN" ]]; then
    DOCKER_CONF="$PWD/.docker"
    mkdir -p "$DOCKER_CONF"
    docker --config="$DOCKER_CONF" login -u="$QUAY_USER" -p="$QUAY_TOKEN" quay.io
    docker --config="$DOCKER_CONF" push "${IMAGE}:${IMAGE_TAG}"
fi