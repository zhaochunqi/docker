#!/bin/sh
set -e

# Default database path in the container
SQLITE_DB_PATH="/data/one-api.db"

# Restore the database if it does not already exist.
if [ -f "$SQLITE_DB_PATH" ]; then
    echo "Database already exists, skipping restore"
else
    echo "No database found, restoring from replica if exists"
    # We use -if-replica-exists so it doesn't fail on the very first run
    litestream restore -if-replica-exists "$SQLITE_DB_PATH"
fi

# Run litestream with the app
# Using exec to replace the shell process
# The command to run linkding is usually just starting the server
# The original image uses bootstrap.sh which starts supervisord etc.
echo "Starting Litestream and new-api ..."
exec litestream replicate -exec "/new-api"
