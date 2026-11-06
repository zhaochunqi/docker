# sub-station (Litestream)

在 `ghcr.io/pinche-team/sub-station:main` 上包一层 [Litestream](https://litestream.io/)：`/data/sub-station.db` 实时备份到 Cloudflare R2，容器启动且库不存在时自动恢复。发布为 `ghcr.io/zhaochunqi/sub-station`。

## 环境变量

| 变量 | 说明 |
| --- | --- |
| `CLOUDFLARE_R2_ACCOUNT_ID` | R2 account id，用于拼 endpoint |
| `CLOUDFLARE_R2_BUCKET_NAME` | R2 bucket 名 |
| `CLOUDFLARE_R2_ACCESS_KEY_ID`、`CLOUDFLARE_R2_SECRET_ACCESS_KEY` | R2 S3 API 凭据 |
| `STRICT_RESTORE` | 默认 `0`；设 `1` 则副本无可用备份时拒绝空库启动 |

凭据由部署方注入，本仓只放 `${...}` 占位符，不含任何真实值。`/data` 必须挂持久卷且对 uid/gid `10001` 可写。R2 里的前缀固定为 `path: sub-station`，同一前缀不要同时跑两个 replicate 实例。

## 首次部署

副本里没有备份时 `litestream restore -if-replica-exists` 返回 0 但不落库文件，容器放行空库启动，应用的 `migrate()` 自动建 schema，同时打 WARN 并写 `/tmp/litestream_empty_restore`。**「首次部署」与「备份丢失」在运行时不可区分**，看到 WARN 必须人工确认是哪种。

## 恢复演练

用一个空的 `/data` 卷、同一套 R2 环境变量另起一个容器（不要与生产实例同时 replicate），确认日志出现 `restoring from replica`、库文件恢复出来且数据对得上，然后销毁演练容器与卷。生产侧想零容忍再设 `STRICT_RESTORE=1`。
