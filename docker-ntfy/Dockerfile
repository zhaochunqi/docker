FROM litestream/litestream:0.5 AS builder

FROM binwiederhier/ntfy:v2.26.3

COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

COPY litestream.yml /etc/litestream.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
