# Build arguments for metadata
ARG VERSION="v1.0.0-rc.22"

# Stage 1: Get Litestream binary
FROM litestream/litestream:0.5 AS builder

# Stage 2: Main image based on Linkding
FROM calciumion/new-api:${VERSION}

# Install Litestream binary from builder stage
COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

# Copy Litestream configuration and custom entrypoint
COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use custom entrypoint that handles database restore and replication
ENTRYPOINT ["/entrypoint.sh"]
