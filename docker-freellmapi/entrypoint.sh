#!/bin/sh
set -e

DB_PATH="${FREEAPI_DB_PATH:-/app/server/data/freeapi.db}"

# Restore the database if it does not already exist.
if [ -f "$DB_PATH" ]; then
	echo "Database already exists, skipping restore"
else
	echo "No database found, restoring from replica if exists"
	litestream restore -if-replica-exists "$DB_PATH"
fi

echo "Starting Litestream and FreeLLMAPI..."
exec litestream replicate -exec "node server/dist/index.js"
