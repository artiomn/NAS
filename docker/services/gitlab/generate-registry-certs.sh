#!/bin/sh

ROOT_DIR=/tank0/apps/docker-registry

mkdir -p "${ROOT_DIR}/certs"

openssl req \
  -newkey rsa:4096 -nodes -sha256 -keyout "${ROOT_DIR}/certs/registry-auth.key" \
  -x509 -days 365 -out "${ROOT_DIR}/certs/registry-auth.crt"

cat "${ROOT_DIR}/certs/registry-auth.key" "${ROOT_DIR}/certs/registry-auth.crt" > \
  "${ROOT_DIR}/certs/registry-auth.pem"

chown git:git ${ROOT_DIR}/certs/*

