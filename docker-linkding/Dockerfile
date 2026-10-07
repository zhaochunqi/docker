# Build arguments for metadata
ARG VERSION="1.47.0"

# Stage 1: Get Litestream binary
FROM litestream/litestream:0.5 AS builder

# Stage 2: Main image based on Linkding
FROM ghcr.io/sissbruecker/linkding:${VERSION}

# OCI standard labels
# See: https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title="Linkding with Litestream" \
      org.opencontainers.image.description="Self-hosted bookmark manager (Linkding) with automated SQLite backup to S3 using Litestream" \
      org.opencontainers.image.url="https://github.com/zhaochunqi/docker" \
      org.opencontainers.image.source="https://github.com/zhaochunqi/docker" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.vendor="zhaochunqi" \
      org.opencontainers.image.authors="zhaochunqi" \
      org.opencontainers.image.documentation="https://github.com/zhaochunqi/docker/blob/main/docker-linkding/README.md"

# Legacy labels for compatibility
LABEL maintainer="zhaochunqi" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.name="Linkding with Litestream" \
      org.label-schema.description="Self-hosted bookmark manager with S3 backup" \
      org.label-schema.url="https://github.com/zhaochunqi/docker" \
      org.label-schema.vcs-url="https://github.com/zhaochunqi/docker" \
      org.label-schema.version="${VERSION}"

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
