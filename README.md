# Personal Docker Images

个人使用的轻量级 Docker 镜像集合。

## 镜像列表

| 镜像名称 | 描述 | GHCR 路径 |
|---------|------|-----------|
| docker-metatube | Metatube （带 litestream 持久化支持） | ghcr.io/zhaochunqi/docker-metatube |
| docker-traefik-cert-dumper | Traefik 证书导出工具 | ghcr.io/zhaochunqi/docker-traefik-cert-dumper |
| docker-traefik-cert-remover | Traefik 证书清理工具 | ghcr.io/zhaochunqi/docker-traefik-cert-remover |
| docker-linkding | Linkding 书签管理器集成 Litestream | ghcr.io/zhaochunqi/linkding |

## 自动构建

使用 GitHub Actions 自动构建。当有代码推送到 main 分支时，会自动检测变更的文件夹并构建对应的 Docker 镜像。

也可以手动触发构建：在 GitHub Actions 页面选择 "Build and Push" workflow，点击 "Run workflow" 手动触发。
