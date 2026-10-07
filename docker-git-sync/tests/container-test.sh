#!/bin/sh
# 容器级验收：验证 git-sync 镜像里的**真 flock 写锁**（本机 macOS 没有 flock，飞行测试覆盖不到）。
#
#   1. 另一个进程持锁时，git-sync 应等满 GIT_SYNC_LOCK_WAIT 后跳过本轮、**不推送**
#   2. 没有持锁者时，git-sync 应把本地改动 commit 并 push 到远端
#   3. 容器里并集合并驱动、锁文件、exclude 都要就位
#
# 用法：sh tests/container-test.sh [镜像名]   默认 git-sync:verify
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(dirname "$HERE")"
IMAGE="${1:-git-sync:verify}"
# 必须落在 Docker Desktop 共享的路径下：macOS 的 /var/folders 不共享给 VM，
# 挂进去会是空的（表现为容器里 "repository does not exist"）。
SHARE="${LGA_CONTAINER_SHARE:-$HOME/.hermes/profiles/coding/cache/scratch}"
mkdir -p "$SHARE"
WORK="$(mktemp -d "$SHARE/container-test-XXXXXX")"
FAILED=0

pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1（期望 [$3] 实际 [$2]）"; fi; }

cleanup() {
  docker rm -f lga-git-sync-test lga-lock-holder >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

git init -q --bare --initial-branch=main "$WORK/origin.git"
git clone -q "$WORK/origin.git" "$WORK/seed" 2>/dev/null || true
mkdir -p "$WORK/seed/journals"
printf '%s\n' '- [[活动日志]]' > "$WORK/seed/journals/2026_10_08.md"
git -C "$WORK/seed" add -A
git -C "$WORK/seed" -c user.name=t -c user.email=t@t commit -q -m seed
git -C "$WORK/seed" push -q origin main
git clone -q "$WORK/origin.git" "$WORK/work"
mkdir -p "$WORK/work/.git"
: > "$WORK/work/.git/logseq-write.lock"
BEFORE="$(git -C "$WORK/origin.git" rev-parse main)"

echo "① 另一个进程持锁 → git-sync 等超时后跳过，且不推送"
docker run -d --name lga-lock-holder -v "$WORK:$WORK" --entrypoint sh "$IMAGE" \
  -c "flock -x '$WORK/work/.git/logseq-write.lock' sleep 25" >/dev/null
sleep 2
docker run -d --name lga-git-sync-test -v "$WORK:$WORK" \
  -e REPO_URL="$WORK/origin.git" -e BRANCH=main -e DEST="$WORK/work" \
  -e INTERVAL_SECONDS=5 -e GIT_SYNC_LOCK_WAIT=3 -e GIT_SYNC_PUSH=1 "$IMAGE" >/dev/null
sleep 12
LOGS="$(docker logs lga-git-sync-test 2>&1 || true)"
docker rm -f lga-git-sync-test >/dev/null 2>&1 || true
case "$LOGS" in
  *"写锁 3s 内没抢到"*) pass "持锁时正确跳过（等满 3s）" ;;
  *) fail "没有出现「写锁超时跳过」：$(printf '%s' "$LOGS" | tail -4)" ;;
esac
check "持锁期间没有推送" "$(git -C "$WORK/origin.git" rev-parse main)" "$BEFORE"
case "$LOGS" in
  *"没有 flock"*) fail "容器里居然没有 flock（镜像缺 util-linux？）" ;;
  *) pass "容器里走的是真 flock（没有降级告警）" ;;
esac

echo
echo "② 没有持锁者 → git-sync 应 commit 并 push"
docker rm -f lga-lock-holder >/dev/null 2>&1 || true
printf '%s\n' '- 23:30 容器里被 API 写出来的条目' >> "$WORK/work/journals/2026_10_08.md"
docker run -d --name lga-git-sync-test -v "$WORK:$WORK" \
  -e REPO_URL="$WORK/origin.git" -e BRANCH=main -e DEST="$WORK/work" \
  -e INTERVAL_SECONDS=3 -e GIT_SYNC_LOCK_WAIT=10 -e GIT_SYNC_PUSH=1 "$IMAGE" >/dev/null
i=0
AFTER="$BEFORE"
while [ "$i" -lt 40 ]; do
  AFTER="$(git -C "$WORK/origin.git" rev-parse main)"
  [ "$AFTER" != "$BEFORE" ] && break
  i=$((i + 1))
  sleep 1
done
LOGS="$(docker logs lga-git-sync-test 2>&1 || true)"
docker rm -f lga-git-sync-test >/dev/null 2>&1 || true
if [ "$AFTER" != "$BEFORE" ]; then
  pass "本地改动被 commit 并推送（${BEFORE} → ${AFTER}）"
else
  fail "没推出去：$(printf '%s' "$LOGS" | tail -6)"
fi
if git -C "$WORK/origin.git" show "main:journals/2026_10_08.md" | grep -q '容器里被 API 写出来的条目'; then
  pass "远端收到了那一条"
else
  fail "远端内容里没有那条改动"
fi
case "$LOGS" in
  *"WARN: 本机没有 flock"*) fail "容器里退化成无锁模式" ;;
  *) pass "全程真锁" ;;
esac

echo
echo "③ 容器内配置齐备"
check "并集驱动已注册" "$(git -C "$WORK/work" config merge.logseq.driver | grep -c merge-logseq.sh)" "1"
check "attributes 指向驱动" "$(cat "$WORK/work/.git/info/attributes")" "*.md merge=logseq"
if grep -q 'logseq-write.lock' "$WORK/work/.git/info/exclude"; then
  pass "锁文件已排除出版本控制"
else
  fail "exclude 里没有锁文件"
fi
if git -C "$WORK/origin.git" show main:journals/2026_10_08.md | grep -q 'logseq-write.lock'; then
  fail "锁文件被提交进了远端（污染 graph 仓）"
else
  pass "锁文件没有被提交进 graph 仓"
fi

echo
if [ "$FAILED" -eq 0 ]; then echo "全部通过"; else echo "失败 $FAILED 项"; fi
exit "$FAILED"
