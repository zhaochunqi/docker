# Gatus Deployment

使用 [Litestream](https://litestream.io/) 为 [Gatus](https://github.com/TwiN/gatus) 提供自动化 SQLite 数据库备份到 S3 的部署方案。

> Gatus 官方镜像基于 `scratch`（无 shell，无法运行 entrypoint 脚本），因此本镜像以 `debian:bookworm-slim` 为基础，携带官方静态 `gatus` 二进制（web UI 已内嵌）与 Litestream 重新打包。

## 功能特性

- 📊 开发者向监控状态页 Gatus（自检端点开箱可用）
- 💾 自动备份 SQLite 数据库到 S3 兼容存储
- 🔄 容器重启时自动从备份恢复数据库

## 使用预构建镜像

### 可用标签

镜像发布在 GitHub Container Registry，支持以下标签：

- `latest`: 最新版本 (推荐用于生产环境)
- `sha-<commit>`: 特定 commit 版本 (用于版本锁定)
- `YYYYMMDD`: 每日构建版本 (用于追踪特定日期的构建)

### 快速运行

```bash
# 1. 配置环境变量
cp .env.example .env
# 编辑 .env 填入你的 S3 凭证

# 2. 直接运行
docker run -d \
  --name gatus \
  -p 8080:8080 \
  --env-file .env \
  -v gatus-data:/data \
  -v ./config.yaml:/config/config.yaml \
  ghcr.io/zhaochunqi/gatus:latest
```

## 从源码构建

```bash
docker build -t gatus-litestream .

docker run -d \
  --name gatus \
  -p 8080:8080 \
  --env-file .env \
  -v gatus-data:/data \
  -v ./config.yaml:/config/config.yaml \
  gatus-litestream
```

### 3. 访问服务

打开浏览器访问: `http://localhost:8080`

## 环境变量

| 变量 | 说明 |
| ----- | ---- |
| `LITESTREAM_S3_ENDPOINT` | S3 端点地址（如 `https://<account>.r2.cloudflarestorage.com`） |
| `LITESTREAM_S3_BUCKET` | 存储桶名称 |
| `LITESTREAM_S3_PATH` | 备份路径（同一 bucket 多服务时建议区分） |
| `LITESTREAM_ACCESS_KEY_ID` | S3 访问密钥 ID |
| `LITESTREAM_SECRET_ACCESS_KEY` | S3 密钥 |
| `STRICT_RESTORE` | 可选；`1` 时「无可用备份」将阻断启动而非放行空库 |

## 工作原理

- **容器启动时**: 如果数据库不存在，自动从 S3 恢复
- **运行期间**: Litestream 持续将数据库变更同步到 S3
- **灾难恢复**: 使用相同的环境变量启动新容器即可自动恢复所有数据

## 配置说明

### Gatus 配置

镜像内置默认 `config.yaml`（sqlite 存储到 `/data/gatus.db` + 自检端点），部署时挂载自己的配置覆盖即可：

```yaml
storage:
  type: sqlite
  path: /data/gatus.db
  caching: true

endpoints:
  - name: my-service
    url: "https://example.org/"
    interval: 5m
    conditions:
      - "[STATUS] == 200"
```

> storage 路径 `/data/gatus.db` 必须与 `litestream.yml` 中的 `dbs[].path` 保持一致。

### Litestream 配置

`litestream.yml` 文件配置备份行为：

- 快照间隔: 24 小时
- 保留时间: 7 天

可根据需要修改 `litestream.yml` 中的配置。

## 致谢

- [Gatus](https://github.com/TwiN/gatus) - 自动化的开发者向状态页
- [Litestream](https://litestream.io/) - SQLite 数据库流式复制工具