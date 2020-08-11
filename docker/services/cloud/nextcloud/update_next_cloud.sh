#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

cd "${SCRIPT_DIR}"

docker-compose pull && \
docker-compose build --pull --force-rm && \
"${SCRIPT_DIR}/patch_iframe.sh"

cd -
