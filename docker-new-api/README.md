# New API Deployment

使用 [Litestream](https://litestream.io/) 为 [New API](https://github.com/QuantumNous/new-api) 提供自动化 SQLite 数据库备份到 S3 的部署方案。

## 功能特性

- 🧠 AI 模型接口管理与分发系统 New API
- 💾 自动备份 SQLite 数据库到 S3 兼容存储
- 🔄 容器重启时自动从备份恢复数据库

## 使用预构建镜像

### 可用标签

镜像发布在 GitHub Container Registry，支持以下标签：

- `latest`: 最新版本
- `sha-<commit>`: 特定 commit 版本（用于版本锁定）
- `YYYYMMDD`: 每日构建版本

### 快速运行

```bash
# 1. 配置环境变量
cp .env.example .env
# 编辑 .env 填入你的 S3 凭证

# 2. 直接运行
docker run -d \
  --name new-api \
  -p 3000:3000 \
  --env-file .env \
  ghcr.io/zhaochunqi/newapi:latest
```

## 从源码构建

### 1. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env` 文件：

```env
LITESTREAM_ACCESS_KEY_ID=your_access_key_id
LITESTREAM_SECRET_ACCESS_KEY=your_secret_access_key
CLOUDFLARE_R2_BUCKET_NAME=your_bucket_name
CLOUDFLARE_R2_ENDPOINT=https://custom-endpoint
CLOUDFLARE_R2_PATH=new-api
```

> 应用本身的环境变量（如 `SESSION_SECRET`、`SQL_DSN` 等）请参考 [New API 官方文档](https://docs.newapi.pro/) 配置。

### 2. 构建并运行

```bash
docker build -t newapi-litestream .

docker run -d \
  --name new-api \
  -p 3000:3000 \
  --env-file .env \
  -v new-api-data:/data \
  newapi-litestream
```

### 3. 访问服务

打开浏览器访问: `http://localhost:3000`，使用默认账号 `root` / `123456` 登录。

## 工作原理

- **容器启动时**: 如果数据库不存在，自动从 S3 恢复
- **运行期间**: Litestream 持续将数据库变更同步到 S3
- **灾难恢复**: 使用相同的环境变量启动新容器即可自动恢复所有数据

## Litestream 配置

`litestream.yml` 配置备份行为（位于 `/etc/litestream.yml`）：

- 快照间隔: 1 小时
- 保留时间: 24 小时
- 同步间隔: 10 分钟

可根据需要修改 `litestream.yml` 中的配置。

## 许可证

本项目采用 [MIT License](LICENSE) 开源。
