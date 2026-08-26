ARG VERSION="v0.9.0"

# Stage 1: Get Litestream binary
FROM litestream/litestream:0.5 AS builder

# Stage 2: Main image based on FreeLLMAPI
FROM ghcr.io/tashfeenahmed/freellmapi:${VERSION}

# Install Litestream binary from builder stage
COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

# Copy Litestream configuration and custom entrypoint
COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint.sh

# Use custom entrypoint that handles database restore and replication
ENTRYPOINT ["/entrypoint.sh"]
