#!/bin/bash

BOOKS_DIR=/books
INITIAL_SYNC_PERIOD=3600
DB_DIR=/data

LAST_SYNC_FILE="${DB_DIR}/last_sync_time"
WORK=1


_term() { 
  echo "Caught SIGTERM signal!" 
  WORK=0
  trap - SIGTERM
  sleep ${INOTIFY_WAIT}
  kill -TERM "$$" 2>/dev/null
}


sync_database() {
    echo "$(date) Database synchronization will be started..."
    calibredb --with-library="${DB_DIR}" add -r -n "${BOOKS_DIR}"
    date +%s > "${LAST_SYNC_FILE}"
    echo "$(date) Database finished..."
}


monitor_directory() {
    MONITORED_DIR="$1"
    RUN_COMMAND="$2"
    MIN_TIME_DIFF_TO_SYNC_DB=${MIN_TIME_DIFF_TO_SYNC_DB:-15}
    INOTIFY_WAIT=${INOTIFY_WAIT:-5}
    DIRECTORY_CHANGED_TIME=$(date +%s)
    DIRECTORY_CHANGED=0

    while [[ ${WORK} -ne 0 ]]; do
        inotify_res=$(inotifywait -t ${INOTIFY_WAIT} -q -r -e close_write,move,create,delete,unmount "${MONITORED_DIR}")
        read -r directory events filename <<<${inotify_res}

        if [[ "$events" = "UMOUNT" ]]; then
            return;
        fi

        if [[ "$events" != "" ]]; then
            echo "Events \"${events}\" were happened!"
            DIRECTORY_CHANGED=1
            DIRECTORY_CHANGED_TIME=$(date +%s)
        fi

        if [[ ${DIRECTORY_CHANGED} -ne 0 ]]; then

            time_diff=$(($(date +%s) - ${DIRECTORY_CHANGED_TIME}))

            if [[ ${time_diff} -ge ${MIN_TIME_DIFF_TO_SYNC_DB} ]]; then
                DIRECTORY_CHANGED=0
                echo "Running database synchronization..."
                ${RUN_COMMAND}
            fi
        fi

    done
}


last_sync_time=$(cat "${LAST_SYNC_FILE}" 2>/dev/null || echo 0)
last_sync_diff=$(($(date +%s) - ${last_sync_time}))

trap _term SIGTERM

if [[ ${last_sync_diff} -ge ${INITIAL_SYNC_PERIOD} ]]; then
    echo "Last sync difference (${last_sync_diff}) > ${INITIAL_SYNC_PERIOD}, starting synchonization..."
    sync_database
else
    echo "Directory \"${BOOKS_DIR}\" doesn't need initial synchronization."
fi

echo "Start monitoring directory \"${BOOKS_DIR}\"..."
monitor_directory "${BOOKS_DIR}" sync_database

