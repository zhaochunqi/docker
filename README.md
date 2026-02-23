# Personal Docker Images

个人使用的轻量级 Docker 镜像集合。

## 镜像列表

- **traefik-cert-remover**: Traefik 证书清理工具

## 自动构建

使用 GitHub Actions 自动构建。当有代码推送到 main 分支时，会自动检测变更的文件夹并构建对应的 Docker 镜像。

也可以手动触发构建：在 GitHub Actions 页面选择 "Build and Push" workflow，点击 "Run workflow" 手动触发。

## 使用方式

```bash
docker pull ghcr.io/<username>/<image-name>:latest
```
