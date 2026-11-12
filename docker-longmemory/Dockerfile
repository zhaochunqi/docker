# LongMemory（带 litestream 持久化）
# 上游 GHCR 镜像 ghcr.io/caviraoss/longmemory 实际未发布；
# npm 上的 longmemory 是旧 OpenMemory lineage（lom/OM_*/8080），不是 GitHub main 的 Hydrograph 版。
# 因此按上游官方 Dockerfile 的流程从源码构建，pin 到固定 commit。
ARG LM_REF=8badf44d48d0d72a07e1ea3daf1ecbd76ae1a357

# Stage 1: Get Litestream binary
FROM litestream/litestream:0.5 AS litestream

# Stage 2: Build the LongMemory tarball from upstream source（上游 Dockerfile build stage 原样）
FROM node:26.13.0-bookworm-slim AS builder
ARG LM_REF
WORKDIR /workspace
RUN corepack enable
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -fsSL "https://github.com/CaviraOSS/LongMemory/archive/${LM_REF}.tar.gz" \
       | tar -xz --strip-components=1 -C /workspace \
    && rm -rf /var/lib/apt/lists/*
RUN pnpm install --frozen-lockfile
RUN pnpm build && pnpm pack --pack-destination /tmp/package

# Stage 3: Runtime image
FROM node:26.13.0-bookworm-slim
ARG LM_REF

# OCI standard labels
LABEL org.opencontainers.image.title="LongMemory with Litestream" \
    org.opencontainers.image.description="LongMemory (Hydrograph) memory engine for AI agents with automated SQLite backup to S3 using Litestream" \
    org.opencontainers.image.url="https://github.com/zhaochunqi/docker" \
    org.opencontainers.image.source="https://github.com/CaviraOSS/LongMemory" \
    org.opencontainers.image.revision="${LM_REF}" \
    org.opencontainers.image.licenses="Apache-2.0" \
    org.opencontainers.image.vendor="zhaochunqi" \
    org.opencontainers.image.authors="zhaochunqi" \
    org.opencontainers.image.documentation="https://github.com/zhaochunqi/docker/blob/main/docker-longmemory/README.md"

# tini 当 PID 1：litestream 只管自己的子进程，容器内孤儿进程（如 healthcheck
# 被 reparent 到 PID 1）无人回收会堆积成僵尸。tini 作为 init 负责 reap。
RUN apt-get update \
    && apt-get install -y --no-install-recommends tini \
    && rm -rf /var/lib/apt/lists/*

# 与上游 Dockerfile runtime stage 一致：安装 pnpm pack 产出的 tarball
COPY --from=builder /tmp/package/*.tgz /tmp/longmemory.tgz
RUN npm install --global --omit=dev /tmp/longmemory.tgz && rm /tmp/longmemory.tgz

ENV NODE_ENV=production \
    LONGMEMORY_HOST=0.0.0.0 \
    LONGMEMORY_PORT=7331 \
    LONGMEMORY_DB_PATH=/data/longmemory.db \
    LONGMEMORY_MCP_HTTP=true

RUN mkdir -p /data

# Install Litestream binary from builder stage
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream

# Copy Litestream configuration and custom entrypoint
COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use custom entrypoint that handles database restore and replication.
# tini 是 PID 1，负责 reap 孤儿进程（见上文）。
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

VOLUME ["/data"]
EXPOSE 7331

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:7331/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
