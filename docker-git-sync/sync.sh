#!/bin/sh
# git-sync
# 将远端 git 仓库克隆到本地并周期拉取（第一步只读）。
#
# 环境变量：
#   REPO_URL          必填，远端 git 地址（https 或 ssh，如 git@github.com:owner/repo.git）
#   BRANCH            默认 main
#   INTERVAL_SECONDS  拉取间隔，默认 60
#   DEST              工作树目录，默认 /logseq-graph
#   GIT_SSH_COMMAND   可选，直接透传给 git（例如已把密钥卷挂载进容器时）
#   SSH_PRIVATE_KEY   可选，私钥内容（含 -----BEGIN ...----- 头尾）；设置后自动构造
#                     GIT_SSH_COMMAND 指向落盘的密钥，无需挂载文件
#   SSH_KNOWN_HOSTS   可选，known_hosts 内容；不设置时用 StrictHostKeyChecking=accept-new
#
# 行为：首次启动 clone（--single-branch）；之后循环 fetch + merge --ff-only。
#       只读模式下工作树应始终等于远端分支；本地分叉/未提交改动会让 merge 失败，
#       此时仅记录日志并等待下次。
set -eu

: "${REPO_URL:?REPO_URL is required (e.g. https://github.com/owner/repo.git)}"
BRANCH="${BRANCH:-main}"
INTERVAL="${INTERVAL_SECONDS:-60}"
DEST="${DEST:-/logseq-graph}"

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

if [ ! -d "$DEST/.git" ]; then
  log "initial clone: $REPO_URL (branch $BRANCH) -> $DEST"
  git clone --branch "$BRANCH" --single-branch "$REPO_URL" "$DEST"
  log "initial clone done: $(git -C "$DEST" rev-parse --short HEAD)"
fi

cd "$DEST"
# 为后续 rebase+push 预置提交身份（只读阶段无副作用）
git config user.name  >/dev/null 2>&1 || git config user.name  "git-sync"
git config user.email >/dev/null 2>&1 || git config user.email "git-sync@localhost"

while true; do
  if git fetch --prune origin "$BRANCH"; then
    if git merge --ff-only "origin/$BRANCH" 2>"$DEST/.git-sync-merge.err"; then
      log "synced: $(git rev-parse --short HEAD)"
    else
      log "merge --ff-only failed (local divergence?): $(cat "$DEST/.git-sync-merge.err")"
    fi
  else
    log "fetch failed (network/credentials), retry in ${INTERVAL}s"
  fi
  sleep "$INTERVAL"
done
