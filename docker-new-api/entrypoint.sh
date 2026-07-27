#!/bin/sh
set -e

# SQLite 文件路径，与 litestream.yml 中的 ${SQLITE_DB_PATH} 保持一致
DB_PATH="${SQLITE_DB_PATH:-/data/one-api.db}"

# 首次启动时从 R2 副本恢复数据库；若副本不存在则跳过（不报错）
if [ -f "$DB_PATH" ]; then
    echo "Database already exists, skipping restore"
else
    echo "No database found, restoring from replica if exists"
    litestream restore -if-replica-exists "$DB_PATH"
fi

echo "Starting Litestream and new-api ..."
exec litestream replicate -exec "/new-api"
