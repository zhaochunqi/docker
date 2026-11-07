# LongMemory Deployment

使用 [Litestream](https://litestream.io/) 为 [LongMemory](https://github.com/CaviraOSS/LongMemory) 提供自动化 SQLite 数据库备份到 S3 的部署方案。

上游官方 GHCR 镜像（`ghcr.io/caviraoss/longmemory`）不存在（仓库 Dockerfile/CI 配了 publish，但实际没推出来），本镜像从 npm 包 `longmemory` 安装，与上游 Dockerfile 的 runtime stage 等价。

## 使用预构建镜像

```bash
docker run -d \
  --name longmemory \
  -p 7331:7331 \
  --env-file .env \
  --env-file .env.litestream \
  -v longmemory-data:/data \
  ghcr.io/zhaochunqi/longmemory
```

## 环境变量

### LongMemory

```env
LONGMEMORY_API_KEY=change-me   # 必填：非 loopback 绑定或开 MCP_HTTP 时上游会拒绝启动
LONGMEMORY_TENANT_ID=default
LONGMEMORY_USER_ID=default
# Embedding：默认 synthetic + hybrid，纯本地无需任何外部 API。
# 要语义检索质量则配 Ollama：
# LONGMEMORY_EMBEDDING_PROVIDER=ollama
# LONGMEMORY_OLLAMA_URL=http://host.docker.internal:11434
# LONGMEMORY_OLLAMA_EMBEDDING_MODEL=nomic-embed-text
```

完整清单见上游 [.env.example](https://github.com/CaviraOSS/LongMemory/blob/main/.env.example)。

### Litestream

```env
LITESTREAM_ACCESS_KEY_ID=your_access_key_id
LITESTREAM_SECRET_ACCESS_KEY=your_secret_key
LITESTREAM_S3_BUCKET=your_bucket_name
LITESTREAM_S3_ENDPOINT=https://custom-endpoint   # 如 Cloudflare R2
LITESTREAM_S3_PATH=longmemory
```

## 行为

- **容器启动时**: 如果数据库不存在,自动从 S3 恢复
- **运行期间**: Litestream 持续将数据库变更同步到 S3
- **灾难恢复**: 使用相同的环境变量启动新容器即可自动恢复所有数据

## 配置说明

### Litestream 配置

`litestream.yml` 文件配置备份行为:

- 快照间隔: 24 小时
- sync-interval: 10 分钟（显式设置，过短会对 S3 发过多 Class A 请求）
- l0-retention-check-interval: 1 小时（v0.5 默认 15s，每次检查发一次 LIST）
- 分层 compaction: 24h 间隔 / 168h 保留

### 应用命令

`entrypoint.sh` 通过 `litestream replicate -exec "longmemory serve --mcp-http"` 启动，等价于上游镜像默认 CMD。
