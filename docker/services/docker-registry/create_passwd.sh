#!/bin/sh

USER="${1:-testuser}"
PASSWORD="${2:-testpassword}"

AUTH_DIR="/tank0/apps/docker-registry/auth"

if [ ! -d "${AUTH_DIR}" ]; then
  mkdir -p "${AUTH_DIR}"
fi

docker run --rm  --entrypoint htpasswd registry:2 -Bbn "${USER}" "${PASSWORD}" >> "${AUTH_DIR}/htpasswd"

