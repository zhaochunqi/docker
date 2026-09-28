# Vikunja

[Vikunja](https://vikunja.io) 待办 / 项目管理服务，数据库用 SQLite 并通过
[Litestream](https://litestream.io/) 持续复制到 Cloudflare R2。

- 镜像：`ghcr.io/zhaochunqi/vikunja`（构建自 `zhaochunqi/docker` 的 `docker-vikunja/`）
- 部署：`my-services` 的 `nodes/node-vps-jp/vikunja`（node `node-vps-jp` / SSH `node-vps2`）
- 域名：`vikunja.zhaochunqi.com`

## 镜像构成

官方 `vikunja/vikunja` 镜像是 **scratch 基础**（没有 shell，跑不了 entrypoint 脚本），
所以这里和 `docker-gatus` 一样：把静态 `vikunja` 二进制和 `litestream` 二进制搬到
`debian:bookworm-slim` 上，再挂自定义 entrypoint。

```
FROM vikunja/vikunja:${VERSION}   # 取 /app/vikunja/vikunja（静态 Go 二进制）
FROM litestream/litestream:0.5     # 取 /usr/local/bin/litestream
→ debian:bookworm-slim + ca-certificates + wget
```

保留上游行为：`USER 1000`、`WORKDIR /app/vikunja`、`EXPOSE 3456`、
`VIKUNJA_SERVICE_ROOTPATH=/app/vikunja/`、`/tmp` 权限 `1777`。

## 数据布局

| 路径                  | 内容                     | 持久化              |
| --------------------- | ------------------------ | ------------------- |
| `/data/vikunja.db`    | SQLite 主库              | named volume + R2   |
| `/app/vikunja/files`  | 附件（上传文件）         | named volume，**未**备份到 R2 |
| `/tmp`                | 数据导出临时目录         | 不持久化，权限 1777 |

> 附件目录不在 Litestream 覆盖范围内。SQLite 里只存附件元数据，文件本体在
> `/app/vikunja/files`。恢复时元数据会回来、文件不会——附件多的实例请另行处理。

## 启动流程

`entrypoint.sh`：

1. `mkdir -p` 库目录与附件目录（uid 1000 需要可写）
2. 库文件不存在 → `litestream restore -if-replica-exists /data/vikunja.db`
3. 副本里没有可用备份时：
   - `STRICT_RESTORE=1` → 直接退出 1（零容忍）
   - 默认 → 打印 `WARN` 并写 `/tmp/litestream_empty_restore` 哨兵文件后放行
4. `exec litestream replicate -exec "/app/vikunja/vikunja"`

「首次部署」和「备份丢了」在运行时不可区分，所以默认是**放行 + 告警**而非阻断。
想零容忍就在 `.env` 里加 `STRICT_RESTORE=1`。

## 配置

Vikunja 读 `config.yml`，也支持环境变量覆盖。嵌套 key 把 `.` 换成 `_`、加
`VIKUNJA_` 前缀即可（例：`first.child` → `VIKUNJA_FIRST_CHILD`）。同名时**环境变量优先**。
完整列表：<https://vikunja.io/docs/config-options/>

本部署通过 `.env` 注入：

| 变量                        | 必填 | 说明                                                    |
| --------------------------- | ---- | ------------------------------------------------------- |
| `VIKUNJA_SERVICE_SECRET`    | 是   | session/JWT 签名密钥。**必须稳定**，变了会踢掉所有登录态 |
| `VIKUNJA_SERVICE_PUBLICURL` | 是   | 外部访问地址                                            |
| `LITESTREAM_*`              | 是   | R2 凭据与备份路径前缀                                   |

镜像里固化的 ENV（`docker-vikunja/Dockerfile`）：

| 变量                      | 值                 | 说明                                     |
| ------------------------- | ------------------ | ---------------------------------------- |
| `VIKUNJA_DATABASE_TYPE`   | `sqlite`           | 上游默认就是 sqlite，这里显式钉住防漂移   |
| `VIKUNJA_DATABASE_PATH`   | `/data/vikunja.db` | 相对上游默认 `/db/vikunja.db` 改到挂载点  |
| `VIKUNJA_SERVICE_ROOTPATH`| `/app/vikunja/`    | 前端与静态资源根目录                     |

### 关于 `service.JWTSecret`

旧文档和大量教程让配 `VIKUNJA_SERVICE_JWTSECRET`。**上游已把它标记为 deprecated**，
值会被复制到 `service.secret`（见 2.5.0 changelog: `(config) Apply deprecated
service.jwtsecret to service.secret`）。本部署直接用新 key `VIKUNJA_SERVICE_SECRET`。
另外 `service.JWTSecret` 曾有「未真正生效、每次启动重新生成」的老 bug
(go-vikunja/vikunja#3307)，多副本时会随机 401——单副本也建议用新 key。

## 本地运行

```bash
docker build -t vikunja-litestream docker-vikunja/

docker run -d --name vikunja -p 3456:3456 \
  --env-file .env \
  -v vikunja-data:/data \
  -v vikunja-files:/app/vikunja/files \
  vikunja-litestream
```

## 灾难恢复

用**相同**的 `LITESTREAM_S3_PATH` 启动新容器即可自动恢复：

```bash
docker volume rm vikunja-data   # 或换一个空 volume
docker run -d --name vikunja-restore -p 3456:3456 \
  --env-file .env \
  -v vikunja-data:/data \
  -v vikunja-files:/app/vikunja/files \
  ghcr.io/zhaochunqi/vikunja:latest
```

## 首次启动

Vikunja 首次启动会自动建表并跑全部 migration。等 `/api/v1/info` 返回 200 后
打开 Web UI 注册第一个账号（**默认开放注册**，注册完记得关掉，见下方注意事项）。

## 注意事项

- **默认开放注册**：`service.enableregistration` 默认为 `true`。公网实例注册完第一个
  账号后应设 `VIKUNJA_SERVICE_ENABLEREGISTRATION=false`。
- **附件不备份**：见上方「数据布局」。
- **SQLite + Litestream**：Litestream 依赖 WAL 模式持续读取 db。Vikunja 长期持有连接，
  与 `gatus`/`linkding` 同一形态，实测无冲突；但 SQLite 写入密集时
  `sync-interval: 10m` 意味着最坏情况丢 10 分钟写入。
- **轮转 / 备份策略**：`snapshot 24h`、`levels 24h × 7d`，与本仓其他 litestream
  服务一致。

## 许可证

Vikunja 本体为 **AGPL-3.0-or-later**。本仓库中重新打包/分发镜像同样受 AGPL 约束。
