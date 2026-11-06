# Stage 1: 取 Litestream 二进制（静态 Go 二进制，与基础镜像发行版无关）
FROM litestream/litestream:0.5 AS builder

# Stage 2: 基于上游 sub-station 镜像包一层备份/恢复
FROM ghcr.io/pinche-team/sub-station:main

# 上游镜像是 oven/bun:1.4.3-alpine，USER app (uid/gid 10001)、WORKDIR /app、
# ENV DB_PATH=/data/sub-station.db、VOLUME /data、ENTRYPOINT ["bun","run","src/index.ts"]。
# 装包 / 写 /etc / chmod 需要 root；启动前必须切回 app，让 litestream 与应用都以
# app 身份读写 /data，否则 restore 出来的库文件与 WAL 属主是 root，应用无法写。
USER root

RUN apk add --no-cache tini

COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# tini 当 PID 1：litestream 只管自己的子进程，容器内孤儿进程（如 healthcheck
# 被 reparent 到 PID 1）无人回收会堆积成僵尸。tini 作为 init 负责 reap。
USER app

# 覆盖上游 ENTRYPOINT：启动命令写回 entrypoint.sh 里（bun run src/index.ts）。
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
