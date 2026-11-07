# 钉死 sdk-go commit，重建可复现；升SDK 时手动改这里（可顺手看 main 上新 provider）
ARG SDK_REF=59ac7f294e9c5b7fac400c5adbc3777a36cff5a4

FROM golang:1.26-alpine AS server-builder
ARG SDK_REF
RUN apk add --no-cache git \
    && git clone https://github.com/metatube-community/metatube-sdk-go /src \
    && cd /src && git checkout ${SDK_REF}
WORKDIR /src
# -tags experimental：AVBASE / av-league / madouqu / theporndb 只在 experimental
# build tag 下注册（engine/register_exp.go），官方镜像不带，所以线上
# /v1/movies/AVBASE/... 一律 provider not found。
RUN CGO_ENABLED=0 go build -ldflags '-w -s' -tags experimental -trimpath \
    -o /metatube-server ./cmd/server

FROM litestream/litestream:0.5 AS builder

FROM alpine:latest
RUN apk add --no-cache tini ca-certificates tzdata

COPY --from=server-builder /metatube-server /metatube-server
COPY --from=builder /usr/local/bin/litestream /usr/local/bin/litestream

# create folder for litestream
RUN mkdir -p /data

COPY entrypoint.sh /entrypoint.sh
COPY litestream.yml /etc/litestream.yml
RUN chmod +x /entrypoint.sh

# tini 当 PID 1：litestream 只管自己的子进程，容器内孤儿进程（如 healthcheck
# 被 reparent 到 PID 1）无人回收会堆积成僵尸。tini 作为 init 负责 reap。
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
