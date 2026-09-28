# Build arguments for metadata
ARG VERSION="2.6.0"

# Stage 1: Get Litestream binary
FROM litestream/litestream:0.5 AS litestream

# Stage 2: Official Vikunja image (scratch-based, static Go binary only)
FROM vikunja/vikunja:${VERSION} AS vikunja

# Stage 3: Rebuild on debian-slim.
# The official image is scratch-based: no shell, so it cannot run the Litestream
# restore/replicate entrypoint. We carry the static vikunja binary + litestream
# onto a shell-bearing base.
FROM debian:bookworm-slim

# Build arguments for metadata
ARG VERSION

LABEL org.opencontainers.image.title="Vikunja with Litestream" \
      org.opencontainers.image.description="Self-hosted task manager (Vikunja) with automated SQLite backup to S3 using Litestream" \
      org.opencontainers.image.url="https://vikunja.io" \
      org.opencontainers.image.source="https://github.com/zhaochunqi/docker" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.licenses="AGPL-3.0" \
      org.opencontainers.image.vendor="zhaochunqi" \
      org.opencontainers.image.authors="zhaochunqi" \
      org.opencontainers.image.documentation="https://github.com/zhaochunqi/docker/blob/main/docker-vikunja/README.md"

# CA certificates for outbound TLS (attachment downloads, litestream S3 replication)
# wget is used by the deployment-side healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates wget \
    && rm -rf /var/lib/apt/lists/*

# Static Vikunja binary (API + embedded frontend) and Litestream binary
COPY --from=vikunja /app/vikunja/vikunja /app/vikunja/vikunja
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream

RUN mkdir -p /data /app/vikunja/files \
    && chown -R 1000:1000 /data /app/vikunja \
    && chmod 1777 /tmp

COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER 1000
WORKDIR /app/vikunja

# database.type defaults to sqlite upstream; pinned explicitly so an upstream
# default flip can't silently point us at a different engine.
# service.secret is the current key; service.JWTSecret is deprecated upstream
# (its value is copied into service.secret).
ENV VIKUNJA_SERVICE_ROOTPATH="/app/vikunja/" \
    VIKUNJA_DATABASE_TYPE="sqlite" \
    VIKUNJA_DATABASE_PATH="/data/vikunja.db"

EXPOSE 3456

# Custom entrypoint: restores the DB from the replica if missing, then runs
# Vikunja under Litestream replication.
ENTRYPOINT ["/entrypoint.sh"]
