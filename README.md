# Personal Docker Images

个人使用的轻量级 Docker 镜像集合。

## 镜像列表

| 镜像名称 | 描述 | GHCR 路径 |
| --------- | ------ | ----------- |
| docker-metatube | Metatube （带 litestream 持久化支持） | ghcr.io/zhaochunqi/metatube |
| docker-new-api | New API（带 litestream 持久化支持） | ghcr.io/zhaochunqi/new-api |
| docker-traefik-cert-dumper | Traefik 证书导出工具 | ghcr.io/zhaochunqi/traefik-cert-dumper |
| docker-traefik-cert-remover | Traefik 证书清理工具 | ghcr.io/zhaochunqi/traefik-cert-remover |
| docker-linkding | Linkding 书签管理器集成 Litestream | ghcr.io/zhaochunqi/linkding |
| docker-ntfy | ntfy 消息推送服务集成 Litestream | ghcr.io/zhaochunqi/ntfy |
| docker-freellmapi | FreeLLMAPI 集成 Litestream | ghcr.io/zhaochunqi/freellmapi |

## 自动构建

使用 GitHub Actions 自动构建。当有代码推送到 main 分支时，会自动检测变更的文件夹并构建对应的 Docker 镜像。

也可以手动触发构建：在 GitHub Actions 页面选择 "Build and Push" workflow，点击 "Run workflow" 手动触发。

每次成功推送会打这些 tag：

| Tag | 说明 |
| ----- | ------ |
| `latest` | 默认分支最新构建 |
| `sha-<short>` | 对应 commit 短 hash，可 pin 到具体构建 |
| `YYYY.MM.DD` | 构建日期（同日多次构建会覆盖该日期 tag） |

## GitOps 自动部署

main 分支构建成功后，会把镜像 digest 通过 `repository_dispatch` 推到 [`zhaochunqi/my-services`](https://github.com/zhaochunqi/my-services)，由那边的 `update-image-ref` + `gitops-sync` 更新并部署服务。

| 镜像 folder | my-services target(s) |
| ------------- | ------------------------ |
| `linkding` | `linkding` |
| `metatube` | `metatube` |
| `new-api` | `new-api` |
| `freellmapi` | `freellmapi` |
| `ntfy` | `ntfy` |
| `traefik-cert-remover` | `traefik-cert-remover-local`, `traefik-cert-remover-jp`, `traefik-cert-remover-us` |
| `traefik-cert-dumper` | `traefik-cert-dumper-jp`, `traefik-cert-dumper-us` |

本仓库需要配置 secret `MY_SERVICES_DISPATCH_TOKEN`（对 `my-services` 有 `Contents: write` 的 PAT）。不能用默认 `GITHUB_TOKEN`，否则 my-services 侧的 push 不会触发 GitOps 同步。
