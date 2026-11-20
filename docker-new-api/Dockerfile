# Build arguments for metadata
ARG VERSION="v1.0.0-rc.22@sha256:d600f20c2781e1a173c2a02f8c33b0c4b1b4e8e5a8b107bafaf2442ae2c9386c"

# Stage 1: Get Litestream binary
FROM litestream/litestream:0.5@sha256:513bff62a88fc0c86c73d27333c41c54c89fe890a7c32a551600adff9309b11b AS builder

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
