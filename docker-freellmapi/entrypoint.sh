#!/bin/sh
set -e

DB_PATH="${FREEAPI_DB_PATH:-/app/server/data/freeapi.db}"

# Restore the database if it does not already exist.
if [ -f "$DB_PATH" ]; then
	echo "Database already exists, skipping restore"
else
	echo "No database found, restoring from replica if exists"
	litestream restore -if-replica-exists "$DB_PATH"
	# -if-replica-exists 在「副本里没有可用备份」时同样返回 0，退出码无法与「首次运行」区分。
	# 恢复成功必然落下 db 文件，所以文件仍不存在 == 确实什么都没恢复回来。
	# 照常启动的话，空库会被复制成最新 generation，之后默认「恢复最新」拿到的也是这个空库。
	if [ ! -f "$DB_PATH" ]; then
		# 副本里没有可用备份：可能确实是首次部署（放行），也可能是备份丢了（必须拦住）。
		if [ "${ALLOW_EMPTY_RESTORE:-0}" = "1" ]; then
			echo "WARN: no usable backup in replica; starting with an EMPTY database (ALLOW_EMPTY_RESTORE=1)"
		else
			echo "FATAL: no usable backup in replica, database was NOT restored"
			echo "FATAL: refusing to start with an empty database"
			echo "FATAL: if this is a genuine first deploy, set ALLOW_EMPTY_RESTORE=1"
			exit 1
		fi
	fi
fi

echo "Starting Litestream and FreeLLMAPI..."
exec litestream replicate -exec "node server/dist/index.js"
