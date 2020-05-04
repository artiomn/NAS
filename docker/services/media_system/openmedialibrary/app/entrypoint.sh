#!/bin/sh
set -eu

umask 0007

echo "Running Open Media Library..."
exec openmedialibrary
