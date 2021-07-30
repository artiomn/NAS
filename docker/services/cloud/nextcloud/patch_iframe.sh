#!/bin/sh

# https://help.nextcloud.com/t/solved-nextcloud-16-how-to-allow-iframe-usage/52278

CONFIG_PATH="/tank0/apps/cloud/nextcloud/"
MY_DOMAIN="system.cloudns.cc"

PROTO="https"
ALLOWED_DOMAINS="'${PROTO}://*.${MY_DOMAIN}', '${PROTO}://www.*.${MY_DOMAIN}'"
ALLOWED_FRAME_ANCESTORS="'${PROTO}://${MY_DOMAIN}', '${PROTO}://www.${MY_DOMAIN}'"

FILE_TO_PATCH="${CONFIG_PATH}/html/lib/public/AppFramework/Http/ContentSecurityPolicy.php"
RESPONSE_FILE="${CONFIG_PATH}/html/lib/private/legacy/OC_Response.php"

# Need to fix rights after the applications update.
chmod -R ug+rx "${CONFIG_PATH}/html/custom_apps"

cp "$FILE_TO_PATCH" "${FILE_TO_PATCH}.bak"
sed -i "
  s|\(allowedFrameDomains *= *\)\[\];|\1[${ALLOWED_DOMAINS}];|;
  / *protected *\$allowedFrameAncestors *= *\[/ {
  :nl
  N;
  s|\( *\)\(\];\)$|\1\1${ALLOWED_FRAME_ANCESTORS},\n\1\2|; T nl;
}" "${FILE_TO_PATCH}"

sed -i "s|\(.*header('X-Frame-Options: SAMEORIGIN');.*\)|//\1|" "${RESPONSE_FILE}"
echo "Complete."

