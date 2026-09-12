# Build arguments for metadata
ARG VERSION="v5.36.0"

# Stage 1: Get Litestream binary
FROM litestream/litestream:0.5 AS litestream

# Stage 2: Official gatus image (scratch-based, only the static binary + CA certs)
FROM ghcr.io/twin/gatus:${VERSION} AS gatus

# Stage 3: Rebuild on debian-slim (official scratch image has no shell for the
# entrypoint script), carrying the static gatus binary and litestream.
FROM debian:bookworm-slim

# CA certificates for TLS (gatus monitoring requests + litestream S3 replication)
# wget is used by the deployment-side healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget \
    && rm -rf /var/lib/apt/lists/*

# Static gatus binary (web UI is embedded in the binary)
COPY --from=gatus /gatus /gatus

# Install Litestream binary from builder stage
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream

# Create folders for litestream data and gatus config
RUN mkdir -p /data /config

# Copy Litestream configuration, default Gatus config and custom entrypoint
COPY config.yaml /config/config.yaml
COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV GATUS_CONFIG_PATH="/config/config.yaml" \
    GATUS_LOG_LEVEL="INFO" \
    PORT="8080"

EXPOSE 8080

# Use custom entrypoint that handles database restore and replication
ENTRYPOINT ["/entrypoint.sh"]