FROM litestream/litestream:0.3 AS builder

#FROM ghcr.io/metatube-community/metatube-server:latest
FROM ghcr.io/metatube-community/metatube-server:dev

COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

# create folder for litestream
RUN mkdir -p /data

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]