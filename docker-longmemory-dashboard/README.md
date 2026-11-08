# LongMemory Dashboard

[LongMemory](https://github.com/CaviraOSS/LongMemory) 的官方 Next.js dashboard，配套 [docker-longmemory](../docker-longmemory/) 使用。

- 无状态（无 SQLite、无 litestream），记忆数据全在后端 API
- 与 docker-longmemory pin **同一个上游 commit**（`LM_REF`），升级时两个 Dockerfile 一起改
- 无登录体系；`LONGMEMORY_API_KEY` 是 dashboard 服务端代理调后端用的，不进浏览器 bundle
- 暴露公网时入口要自己加认证（如 Traefik `tinyauth@docker` 中间件）；纯内网可裸跑

## 运行

```bash
docker run -d -p 3000:3000 \
  -e LONGMEMORY_API_URL=http://longmemory:7331 \
  -e LONGMEMORY_API_KEY=your-secret-api-key \
  ghcr.io/zhaochunqi/longmemory-dashboard
```

环境变量见上游 `dashboard/.env.local.example`：

- `LONGMEMORY_API_URL`：LongMemory API 地址（容器网络内用服务名）
- `LONGMEMORY_API_KEY`：后端的 bearer token，服务端持有
