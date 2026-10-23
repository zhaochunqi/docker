# Snell 是 nssurge 的闭源免费软件,官方只发布二进制:
# https://kb.nssurge.com/surge-knowledge-base/release-notes/snell
# 构建期从 dl.nssurge.com 下载指定版本,运行期只有这一个二进制。
# 注意:官方不发布校验和,升级 = 改 SNELL_VERSION 重新构建。
ARG SNELL_VERSION=v6.0.0

FROM debian:bookworm-slim AS downloader

ARG SNELL_VERSION
ARG TARGETARCH
# dl.nssurge.com 的命名:amd64 同名,arm64 叫 aarch64
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/* \
    && case "${TARGETARCH}" in \
         amd64) PLAT=amd64 ;; \
         arm64) PLAT=aarch64 ;; \
         *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSLO "https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-${PLAT}.zip" \
    && unzip -o -j "snell-server-${SNELL_VERSION}-linux-${PLAT}.zip" -d /out \
    && chmod +x /out/snell-server

# 官方二进制动态链接 glibc + libstdc++(musl/alpine 直接 exec not found),
# DNS 解析也依赖 glibc 语义,网络服务不用 alpine
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends tini libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=downloader /out/snell-server /usr/local/bin/snell-server
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# tini 当 PID 1 回收僵尸进程,与 docker-ntfy 同款约定
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
