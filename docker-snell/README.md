# docker-snell

[nssurge Snell](https://kb.nssurge.com/surge-knowledge-base/release-notes/snell) 服务端容器化封装。
Snell 是闭源免费软件,官方只发布二进制,本镜像在**构建期**从 `dl.nssurge.com` 下载指定版本(见 Dockerfile 的 `SNELL_VERSION`),运行期只有 `snell-server` 单个静态二进制。官方不发布校验和,升级 = 改 `SNELL_VERSION` 触发重新构建。

## 环境变量

| 变量 | 默认 | 说明 |
| ---- | ---- | ---- |
| `PSK` | 随机生成 | **生产必填**。官方建议 32 字符随机串;不填则每次重启换一把,客户端立即失配 |
| `PORT` | `8388` | 监听端口 |
| `LISTEN` | `0.0.0.0:${PORT}` | 完整 listen 值,双栈传 `0.0.0.0:8388,[::]:8388` |
| `MODE` | `default` | `default`(混淆+AES)/ `unshaped`(仅 AES,约 +10% 吞吐)/ `unsafe-raw`(仅限可信内网)。**两端必须一致** |
| `DNS_IP_PREFERENCE` | `default` | `default / prefer-ipv4 / prefer-ipv6 / ipv4-only / ipv6-only`,v6 中取代旧 `ipv6` 开关 |
| `SNELL_CONF` | - | 挂载完整配置文件的路径,设置后忽略以上所有模板变量 |

无状态服务,不需要卷。v6 的 UDP relay 走同一条 TCP 连接(UDP over TCP),**只需暴露一个 TCP 端口**;v5 时代的 `udp-port`/QUIC Proxy Mode 在 v6 已移除。

## 使用

```yaml
services:
  snell:
    image: ghcr.io/zhaochunqi/snell:latest
    ports:
      - "8389:8389"
    environment:
      - PORT=8389
      - PSK=${SNELL_PSK}
      - MODE=default
      - DNS_IP_PREFERENCE=prefer-ipv4
    restart: unless-stopped
```

Surge 客户端对应策略行(要求 Surge Mac ≥ 6.7 / iOS ≥ 5.20):

```
名称 = snell, <host>, 8389, psk=<同款 PSK>, version=6, mode=default, reuse=true
```

## 构建平台

linux/amd64 单架构(家宽 Mac xiaoken 是 Intel)。注意 snell v6 官方 macOS 二进制只有 arm64,Intel Mac 上跑 v6 只能走 linux-amd64 容器——这正是本镜像存在的理由。Dockerfile 保留了 TARGETARCH 的 aarch64 分支,将来有 ARM 机器时在 workflow 加回 setup-qemu-action 和 platforms 条件即可。
