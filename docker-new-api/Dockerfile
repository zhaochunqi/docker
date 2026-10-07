# Build arguments for metadata
ARG VERSION="v1.0.0-rc.22"

# Stage 1: Get Litestream binary
FROM litestream/litestream:0.5 AS builder

# Stage 2: Main image based on Linkding
FROM calciumion/new-api:${VERSION}

# tini 当 PID 1：litestream 只管自己的子进程，容器内孤儿进程（如 healthcheck
# 被 reparent 到 PID 1）无人回收会堆积成僵尸。tini 作为 init 负责 reap。
RUN apt-get update \
    && apt-get install -y --no-install-recommends tini \
    && rm -rf /var/lib/apt/lists/*

# Install Litestream binary from builder stage
COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

# Copy Litestream configuration and custom entrypoint
COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use custom entrypoint that handles database restore and replication.
# tini 是 PID 1，负责 reap 孤儿进程（见上文）。
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
