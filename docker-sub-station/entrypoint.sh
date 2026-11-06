#!/bin/sh
set -e

# 与上游镜像 ENV DB_PATH 及 litestream.yml 的 dbs[].path 保持一致
DB_PATH="/data/sub-station.db"

# Restore the database if it does not already exist.
if [ -f "$DB_PATH" ]; then
    echo "Database already exists, skipping restore"
else
    echo "No database found, restoring from replica if exists"
    litestream restore -if-replica-exists "$DB_PATH"
    # -if-replica-exists 在「副本无可用备份」时返回 0 且不落文件（官方即如此设计，用于幂等/首次部署）。
    # 因此「db 缺失 + 副本无备份」== 首次部署 OR 备份丢失，二者运行时不可区分。
    # 应用启动会自动跑 migrate()，空库启动能建好 schema；故默认放行但打高亮告警，
    # 让静默空库变可见（标记文件 /tmp/litestream_empty_restore 可供监控）。
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

# Run litestream with the upstream app as the subprocess.
# WORKDIR /app 继承上游，所以直接跑 src/index.ts；-exec 覆盖上游 ENTRYPOINT 的启动命令。
exec litestream replicate -exec "bun run src/index.ts"
