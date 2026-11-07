#!/bin/sh
set -e

DB_PATH="/data/longmemory.db"

# Restore the database if it does not already exist.
if [ -f "$DB_PATH" ]; then
    echo "Database already exists, skipping restore"
else
    echo "No database found, restoring from replica if exists"
    # We use -if-replica-exists so it doesn't fail on the very first run
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

# Run litestream with the app as the subprocess.
# LongMemory 的数据全部在 SQLite，等价于上游镜像默认命令 `longmemory serve --mcp-http`。
echo "Starting Litestream and LongMemory..."
exec litestream replicate -exec "longmemory serve --mcp-http"
