#!/bin/sh
# git-sync：把远端仓库同步到本地工作树，并把**本地产生的改动**（logseq-graph-api 写出来的）
# commit & push 回去。双向：pull（fetch + merge）+ push。
#
# 环境变量：
#   REPO_URL             必填，远端 git 地址（https 或 ssh）
#   BRANCH               默认 main
#   INTERVAL_SECONDS     周期秒数，默认 600
#   DEST                 工作树目录，默认 /repo
#   GIT_SSH_COMMAND      可选，直接透传 git
#   SSH_PRIVATE_KEY      可选，私钥内容（落盘构造 GIT_SSH_COMMAND）
#   SSH_KNOWN_HOSTS      可选，known_hosts 内容
#   GIT_SYNC_PUSH        设为 0 则只拉不推（回退到旧的只读行为）
#   GIT_SYNC_LOCK_WAIT   抢写锁最长等待秒数，默认 60
#   GIT_SYNC_AUTHOR_NAME / GIT_SYNC_AUTHOR_EMAIL   提交署名
#
# **与 logseq-graph-api 的硬约定（两边必须一致，否则会互相盖掉对方）**：
#   写锁文件 = <DEST>/.git/logseq-write.lock，双方都 flock 独占；
#   API 在每次写请求期间持有，本脚本在「commit + merge + push」整段持有；
#   两边都是「先跨进程锁、后进程内」的顺序，不交叉持锁，不成环。
#
# 冲突策略：markdown 走 merge-logseq.sh 的**行多重集并集**（journal 是追加型文件，
#   正确语义是两边条目都要在；完全相同的行去重）。并集不掉的冲突 →
#   **停下不推**、打印冲突文件清单、工作树保持原样等人工处理。
#   绝不 `push --force`、绝不 `checkout --ours/--theirs`（那会静默丢内容）。
set -eu

: "${REPO_URL:?REPO_URL is required (e.g. https://github.com/owner/repo.git)}"
BRANCH="${BRANCH:-main}"
INTERVAL="${INTERVAL_SECONDS:-600}"
DEST="${DEST:-/repo}"
PUSH_ENABLED="${GIT_SYNC_PUSH:-1}"
LOCK_WAIT="${GIT_SYNC_LOCK_WAIT:-60}"
AUTHOR_NAME="${GIT_SYNC_AUTHOR_NAME:-git-sync}"
AUTHOR_EMAIL="${GIT_SYNC_AUTHOR_EMAIL:-git-sync@localhost}"

log() { echo "[git-sync] $(date -u +%Y-%m-%dT%H:%M:%SZ) $*"; }

# ---- SSH 支持：优先用户显式 GIT_SSH_COMMAND，否则用 SSH_PRIVATE_KEY 落盘构造 ----
if [ -z "${GIT_SSH_COMMAND:-}" ] && [ -n "${SSH_PRIVATE_KEY:-}" ]; then
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  printf '%s\n' "$SSH_PRIVATE_KEY" > "$HOME/.ssh/id_ed25519"
  chmod 600 "$HOME/.ssh/id_ed25519"
  if [ -n "${SSH_KNOWN_HOSTS:-}" ]; then
    printf '%s\n' "$SSH_KNOWN_HOSTS" > "$HOME/.ssh/known_hosts"
    chmod 600 "$HOME/.ssh/known_hosts"
    GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts"
  else
    GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new"
  fi
  export GIT_SSH_COMMAND
  log "SSH auth configured from SSH_PRIVATE_KEY"
fi

mkdir -p "$DEST"

# 绑定卷/挂载目录的属主可能与容器 uid 不一致，显式豁免 safe.directory
git config --global --add safe.directory "$DEST" 2>/dev/null || true

if [ ! -d "$DEST/.git" ]; then
  log "initial clone: $REPO_URL (branch $BRANCH) -> $DEST"
  git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$DEST"
  log "initial clone done: $(git -C "$DEST" rev-parse --short HEAD)"
fi

cd "$DEST"
git config user.name  >/dev/null 2>&1 || git config user.name  "$AUTHOR_NAME"
git config user.email >/dev/null 2>&1 || git config user.email "$AUTHOR_EMAIL"

# ---- markdown 的并集合并驱动（写在 .git 下，不动 graph 仓本身、不需要它提交任何配置）----
git config merge.logseq.name "union merge for Logseq markdown"
git config merge.logseq.driver "/merge-logseq.sh %O %A %B"
mkdir -p "$DEST/.git/info"
printf '%s\n' '*.md merge=logseq' > "$DEST/.git/info/attributes"
# 中间产物别进版本控制：原子写的临时文件、写锁、旧的 merge stderr 文件
{
  printf '%s\n' '.*.tmp-*'
  printf '%s\n' 'logseq-write.lock'
  printf '%s\n' '.git-sync-merge.err'
} >> "$DEST/.git/info/exclude"

LOCK_FILE="$DEST/.git/logseq-write.lock"
TMP_MERGE="$(mktemp)"
TMP_PUSH="$(mktemp)"
trap 'rm -f "$TMP_MERGE" "$TMP_PUSH"' EXIT

# 一轮同步：本地改动提交 → fetch → 并入 → 推。返回 0 表示这一轮全部完成。
sync_once() {
  # 1) 本地改动（API 写出来的新块）先落成 commit —— 不提交就没法 push 出去
  if [ -n "$(git status --porcelain)" ]; then
    git add -A
    if git commit -q -m "sync: $(date -u +%Y-%m-%dT%H:%M:%SZ) 自动提交（API 写入）"; then
      log "committed local changes -> $(git rev-parse --short HEAD)"
    else
      log "commit failed (nothing staged?)"
      return 1
    fi
  fi

  # 2) 拉远端的
  # 不带显式 refspec：`git fetch origin main` 在远端还没有该分支时会直接 fatal
  # （couldn't find remote ref main），而配置里的 refspec 会正常处理空远端。
  if ! git fetch --prune origin; then
    log "fetch failed (network/credentials), retry in ${INTERVAL}s"
    return 1
  fi

  # 3) 并入远端：markdown 走并集驱动；并集不掉就停下，不推
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$BRANCH")" ]; then
    if git merge --no-edit "origin/$BRANCH" >"$TMP_MERGE" 2>&1; then
      log "merged origin/$BRANCH -> $(git rev-parse --short HEAD)"
    else
      log "MERGE 未解决：停止推送，工作树保持原样等人工处理"
      git diff --name-only --diff-filter=U | while read -r f; do log "  冲突文件: $f"; done
      sed 's/^/[git-sync] /' "$TMP_MERGE" >&2
      return 2
    fi
  fi

  # 4) 推本地新提交
  if [ "$PUSH_ENABLED" = "0" ]; then
    log "push disabled (GIT_SYNC_PUSH=0); up to date at $(git rev-parse --short HEAD)"
    return 0
  fi
  if [ -z "$(git log "origin/$BRANCH..HEAD" --oneline)" ]; then
    log "up to date: $(git rev-parse --short HEAD)"
    return 0
  fi
  if git push origin "HEAD:$BRANCH" >"$TMP_PUSH" 2>&1; then
    log "pushed $(git rev-parse --short HEAD)"
    return 0
  fi
  log "push 被拒（远端又前进了）→ 下一轮 fetch+merge+push 重试：$(tail -n 2 "$TMP_PUSH" | tr '\n' ' ')"
  return 3
}

# 写锁保护：与 API 用同一个锁文件。flock 在 debian-slim 里有（util-linux）
run_locked() {
  if command -v flock >/dev/null 2>&1; then
    if ! flock -w "$LOCK_WAIT" 9; then
      log "写锁 ${LOCK_WAIT}s 内没抢到（API 长时间持锁？）→ 本轮跳过"
      return 1
    fi
    set +e
    sync_once
    rc=$?
    set -e
    flock -u 9
    return "$rc"
  fi
  # 本地调试（macOS 无 flock）才会走到这：跨进程互斥失效，必须显式喊出来
  log "WARN: 本机没有 flock —— 跨进程写锁失效（仅限调试，别在生产这样跑）"
  set +e
  sync_once
  rc=$?
  set -e
  return "$rc"
}

log "sync loop start: repo=$REPO_URL branch=$BRANCH interval=${INTERVAL}s dest=$DEST push=$PUSH_ENABLED lock=$LOCK_FILE"
exec 9>"$LOCK_FILE"
while true; do
  run_locked || true
  sleep "$INTERVAL"
done
