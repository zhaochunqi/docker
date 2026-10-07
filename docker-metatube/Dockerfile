FROM litestream/litestream:0.5 AS builder

FROM ghcr.io/metatube-community/metatube-server:1.4.0

RUN apk add --no-cache tini

COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

# create folder for litestream
RUN mkdir -p /data

COPY entrypoint.sh /entrypoint.sh
COPY litestream.yml /etc/litestream.yml
RUN chmod +x /entrypoint.sh

# tini 当 PID 1：litestream 只管自己的子进程，容器内孤儿进程（如 healthcheck
# 被 reparent 到 PID 1）无人回收会堆积成僵尸。tini 作为 init 负责 reap。
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
