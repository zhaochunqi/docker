# docker-git-sync

把远端 git 仓库同步到本地工作树，并**把本地产生的改动 commit & push 回去**（双向）。
为 [logseq-graph-api](https://github.com/xiaolutech/logseq-graph-api) 这类「往工作树里写文件」的服务提供持久化通路。

## 环境变量

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `REPO_URL` | 必填 | 远端地址（https 或 ssh） |
| `BRANCH` | `main` | 分支 |
| `INTERVAL_SECONDS` | `600` | 每轮间隔。**别设太小**：每次合并/落盘都会触发 graph-api 重索引（60s 时实测 CPU 常驻） |
| `DEST` | `/repo` | 工作树目录（就是 graph 目录） |
| `GIT_SYNC_PUSH` | `1` | 设 `0` 退回「只拉不推」 |
| `GIT_SYNC_LOCK_WAIT` | `60` | 抢写锁最长等待秒数 |
| `GIT_SYNC_AUTHOR_NAME` / `GIT_SYNC_AUTHOR_EMAIL` | `git-sync` / `git-sync@localhost` | 自动提交的署名 |
| `SSH_PRIVATE_KEY` | — | 私钥内容（含 BEGIN/END），落盘后构造 `GIT_SSH_COMMAND` |
| `SSH_KNOWN_HOSTS` | — | known_hosts 内容；不设则 `StrictHostKeyChecking=accept-new` |
| `GIT_SSH_COMMAND` | — | 直接透传 git（优先于上面的密钥注入） |

## 一轮同步做什么

1. **本地有改动 → 先提交**（`git add -A` + 自动提交，署名见上）——不提交就没得推；
2. `git fetch --prune origin`；
3. HEAD 与 `origin/$BRANCH` 不同 → `git merge --no-edit origin/$BRANCH`（markdown 走并集驱动，见下）；
4. 有本地新提交 → `git push origin HEAD:$BRANCH`。被拒（远端又前进）→ 下一轮重试，**从不 force push**。

## 与 logseq-graph-api 的写锁约定（**两边必须一致**）

- 锁文件：**`<DEST>/.git/logseq-write.lock`**，双方 `flock` 独占；
- 本容器在 **commit + merge + push 整段**持有；API 在**每个写请求**期间持有；
- 取锁顺序都是「先跨进程锁、后进程内锁」，不交叉持锁 → 不成环；
- 不加锁的后果不是报错，而是**静默丢内容**：API 基于旧内容算出整页文本会覆盖这里刚合进来的远端改动。

`flock` 来自 util-linux（debian-slim 自带）。**本机没有 flock 时脚本会显式告警并降级为无锁**，
只用于本地调试——容器里永远走真锁（`tests/container-test.sh` 钉住了这条）。

## markdown 的并集合并（`merge-logseq.sh`）

journal 是**追加型**文件：两台设备各往同一天日记的同一段位下追加一行时，git 会判为同一区域冲突。
对追加型数据，正确语义是**并集**，不是选一边。所以 `.git/info/attributes` 里给 `*.md` 挂上
`merge=logseq` 驱动，冲突区域按「行多重集并集」解：

- 每行取 `max(ours 份数, theirs 份数)`：先按 ours 顺序输出，再补 theirs 独有的行；
- 两边各追加不同条目 → **都在**；两边写了完全相同的行 → **只留一份**（去重）；
- 冲突区里出现不是「块行（`-`）/ 续行（tab/空格）/ 空行」的行 → **不猜**：保留冲突标记、非 0 退出，
  随即停止推送并打印冲突文件清单，等人工处理（fail-closed，绝不静默丢内容）；
- `merge` 与 `zdiff3` 两种冲突标记风格都认（本机全局 `merge.conflictStyle=zdiff3`，
  容器里默认 `merge`；只认一种会把 base 段错当成 ours）。

这些配置都写在 `.git/` 下（`info/attributes`、`info/exclude`、`merge.logseq.*`），
**不需要目标 graph 仓提交任何配置**。

## 测试

```bash
sh tests/flight-test.sh      # 本地 bare 仓模拟两台设备：并集合并 / 去重 / fail-closed / 真推 / 冲突不推
sh tests/container-test.sh   # 容器级：真 flock 互斥、持锁时跳过不推、无锁时 commit+push 成功
```

`container-test.sh` 需要先构建镜像（`docker build -t git-sync:verify .`）。
