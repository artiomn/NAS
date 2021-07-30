#!/usr/bin/env bash

export SRC_DIR="${1}"
export OLD=${2:-"12"}
export NEW=${3:-"13"}

if [ -z "${SRC_DIR}" ]; then
    echo "$(basename $0) <database_path> [from_version (def: ${OLD})] [to_version (def: ${NEW})]" >&2
    exit 1
fi

set -xeuo pipefail

docker run \
  -w /tmp/upgrade \
  -v "$SRC_DIR/postgres-$NEW-upgrade:/tmp/upgrade" \
  -v "$SRC_DIR/db:/var/lib/postgresql/$OLD/data" \
  -v "$SRC_DIR/db-$NEW:/var/lib/postgresql/$NEW/data" \
  "tianon/postgres-upgrade:$OLD-to-$NEW"

mv "$SRC_DIR/"{db,db-$OLD}
mv "$SRC_DIR/"{db-$NEW,db}

curl -fsSL -o "$SRC_DIR/postgres-$NEW-upgrade/optimize.sh" https://raw.githubusercontent.com/sourcegraph/sourcegraph/master/cmd/server/rootfs/postgres-optimize.sh

docker run \
  --entrypoint "/bin/bash" \
  -w /tmp/upgrade \
  -v "$SRC_DIR/postgres-$NEW-upgrade:/tmp/upgrade" \
  -v "$SRC_DIR/db:/var/lib/postgresql/data" \
  "postgres:$NEW" \
  -c 'chown -R postgres $PGDATA . && gosu postgres bash ./optimize.sh $PGDATA'

# Allow connections from containers.
echo "host    all             all             172.0.0.0/8            trust" >> "$SRC_DIR/pg_hba.conf"

