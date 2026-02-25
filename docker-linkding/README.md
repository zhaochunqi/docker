# Linkding Deployment

使用 [Litestream](https://litestream.io/) 为 [Linkding](https://github.com/sissbruecker/linkding) 提供自动化 SQLite 数据库备份到 S3 的部署方案。

## 功能特性

- 🔖 自托管书签管理器 Linkding
- 💾 自动备份 SQLite 数据库到 S3 兼容存储
- 🔄 容器重启时自动从备份恢复数据库

## 一键部署

### 部署到 Koyeb

[![Deploy to Koyeb](https://www.koyeb.com/static/images/deploy/button.svg)](https://app.koyeb.com/deploy?name=linkding&type=docker&image=ghcr.io%2Fzhaochunqi%2Flinkding&instance_type=free&regions=was&instances_min=0&autoscaling_sleep_idle_delay=300&env%5BLITESTREAM_ACCESS_KEY_ID%5D=YOUR_ACCESS_KEY_ID&env%5BLITESTREAM_S3_BUCKET%5D=YOUR_BUCKET_NAME&env%5BLITESTREAM_S3_ENDPOINT%5D=https%3A%2F%2Fyour-s3-endpoint.com&env%5BLITESTREAM_S3_PATH%5D=YOUR_PATH&env%5BLITESTREAM_SECRET_ACCESS_KEY%5D=YOUR_SECRET_ACCESS_KEY&ports=9090%3Bhttp%3B%2F&hc_protocol%5B9090%5D=tcp&hc_grace_period%5B9090%5D=5&hc_interval%5B9090%5D=30&hc_restart_limit%5B9090%5D=3&hc_timeout%5B9090%5D=5&hc_path%5B9090%5D=%2F&hc_method%5B9090%5D=get)

> **注意**: 点击部署按钮后,请在 Koyeb 控制台中填入你自己的 S3 凭证:
> - `LITESTREAM_ACCESS_KEY_ID`: 你的 S3 访问密钥 ID
> - `LITESTREAM_SECRET_ACCESS_KEY`: 你的 S3 密钥
> - `LITESTREAM_S3_BUCKET`: 你的 S3 存储桶名称
> - `LITESTREAM_S3_ENDPOINT`: 你的 S3 端点地址 (如使用 Cloudflare R2)
> - `LITESTREAM_S3_PATH`: 备份路径名称

## 使用预构建镜像

### 可用标签

镜像发布在 GitHub Container Registry,支持以下标签:

- `latest`: 最新版本 (推荐用于生产环境)
- `sha-<commit>`: 特定 commit 版本 (用于版本锁定)
- `YYYYMMDD`: 每日构建版本 (用于追踪特定日期的构建)

### 快速运行

使用预构建镜像,无需本地构建:

```bash
# 1. 配置环境变量
cp .env.example .env
# 编辑 .env 填入你的 S3 凭证

# 2. 直接运行
docker run -d \
  --name linkding \
  -p 9090:9090 \
  --env-file .env \
  ghcr.io/zhaochunqi/linkding:latest
```

## 从源码构建

### 1. 配置环境变量

复制示例配置文件并填入你的 S3 凭证:

```bash
cp .env.example .env
```

编辑 `.env` 文件:

```env
LITESTREAM_ACCESS_KEY_ID=your_access_key_id
LITESTREAM_SECRET_ACCESS_KEY=your_secret_access_key
LITESTREAM_S3_BUCKET=your_bucket_name
LITESTREAM_S3_ENDPOINT=https://custom-endpoint
LITESTREAM_S3_PATH=linkding
```

### 2. 构建并运行

```bash
docker build -t linkding-litestream .

docker run -d \
  --name linkding \
  -p 9090:9090 \
  --env-file .env \
  -v linkding-data:/etc/linkding/data \
  linkding-litestream
```

### 3. 访问服务

打开浏览器访问: `http://localhost:9090`

## 工作原理

- **容器启动时**: 如果数据库不存在,自动从 S3 恢复
- **运行期间**: Litestream 持续将数据库变更同步到 S3
- **灾难恢复**: 使用相同的环境变量启动新容器即可自动恢复所有数据

## 配置说明

### Litestream 配置

`litestream.yml` 文件配置备份行为:

- 快照间隔: 24 小时
- 保留时间: 7 天

可根据需要修改 `litestream.yml` 中的配置。

## 许可证

本项目采用 [MIT License](LICENSE) 开源。

## 致谢

- [Linkding](https://github.com/sissbruecker/linkding) - 优秀的自托管书签管理器
- [Litestream](https://litestream.io/) - SQLite 数据库流式复制工具
