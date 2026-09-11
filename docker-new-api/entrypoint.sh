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
    # -if-replica-exists 在「副本无可用备份」时返回 0 且不落文件（官方即如此设计，用于幂等/首次部署）。
    # 因此「db 缺失 + 副本无备份」== 首次部署 OR 备份丢失，二者运行时无法区分。
    # 初始化很频繁，故默认放行空库启动，但打高亮告警让静默空库变可见；
    # 想零容忍的服务设 STRICT_RESTORE=1，会把这条从「放行+告警」翻成「阻断」。
    if [ ! -f "$DB_PATH" ]; then
        if [ "${STRICT_RESTORE:-0}" = "1" ]; then
            echo "FATAL: no usable backup in replica and STRICT_RESTORE=1; refusing to start with an empty database"
            exit 1
        else
            echo "WARN: no usable backup in replica; starting with an EMPTY database"
            echo "WARN: fresh init or lost backup (indistinguishable here) -- monitor /tmp/litestream_empty_restore"
            touch /tmp/litestream_empty_restore 2>/dev/null || true
        fi
    fi
fi

echo "Starting Litestream and new-api ..."
exec litestream replicate -exec "/new-api"
