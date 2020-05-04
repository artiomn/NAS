#!/bin/sh

# https://help.nextcloud.com/t/solved-nextcloud-16-how-to-allow-iframe-usage/52278

CONFIG_PATH="/tank0/apps/cloud/nextcloud/"
MY_DOMAIN="system.cloudns.cc"

PROTO="https"
ALLOWED_DOMAIN="${PROTO}://*.${MY_DOMAIN}"
ALLOWED_FRAME_ANCESTOR="${PROTO}://${MY_DOMAIN}"

FILE_TO_PATCH="${CONFIG_PATH}/html/lib/public/AppFramework/Http/ContentSecurityPolicy.php"
RESPONSE_FILE="${CONFIG_PATH}/html/lib/private/legacy/response.php"

cp "$FILE_TO_PATCH" "${FILE_TO_PATCH}.bak"
sed -i "
  s|\(allowedFrameDomains *= *\)\[\];|\1['${ALLOWED_DOMAIN}'];|;
  / *protected *\$allowedFrameAncestors *= *\[/ {
  :nl
  N;
  s|\( *\)\(\];\)$|\1\1'${ALLOWED_FRAME_ANCESTOR}',\n\1\2|; T nl;
}" "${FILE_TO_PATCH}"

sed -i "s|\(.*header('X-Frame-Options: SAMEORIGIN');.*\)|//\1|" "${RESPONSE_FILE}"

