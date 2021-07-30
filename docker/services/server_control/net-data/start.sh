#!/bin/sh

HDDTEMP_CONFIG="/etc/default/hddtemp"

if [ ! -e "${HDDTEMP_CONFIG}" ]; then
    echo "hddtemp is not installed or configured!" >&2
    exit 1
fi

DOCKER_ADDR="$(ip a show docker0 |awk '/inet .*$/ { sub(/\/[^\/]+$/, ""); print($2); }')"
HDDTEMP_INTERFACE="$(awk 'BEGIN {FS = "=";} /^.*INTERFACE=/ {gsub(/"/, ""); sub(/[#[:space:]]*.*$/, "", $2); print($2);}' "${HDDTEMP_CONFIG}")"

echo "Hddtemp interface: ${HDDTEMP_INTERFACE}"
echo "Docker address: ${DOCKER_ADDR}"

if [ "${HDDTEMP_INTERFACE}" != "${DOCKER_ADDR}" ]; then
    echo "Replacing..."
    sed -i "s/\\s*INTERFACE=.*/INTERFACE=\"${DOCKER_ADDR}\"/" "${HDDTEMP_CONFIG}"
fi

systemctl enable hddtemp
systemctl restart hddtemp

sed -i "s/^host.*/host: \"${DOCKER_ADDR}\"/" hddtemp.conf

docker-compose down && docker-compose up -d

