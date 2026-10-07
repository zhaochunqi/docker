#!/bin/sh
# docker-git-sync 的飞行测试：用本地 bare 仓模拟「两台设备 + git-sync」，验证写回链真的对。
#
# 覆盖：
#   1. 两边各往同一天日记追加**不同**条目 → 并集合并后两边都在、无冲突标记
#   2. 两边追加**完全相同**的行 → 去重只留一份
#   3. 冲突区里出现结构性可疑的行（不是块行/续行）→ 驱动 fail-closed，保留标记、非 0 退出
#   4. sync.sh 真跑一轮：本地改动被 commit 并 push 回远端
#   5. 并集不掉的冲突下 sync.sh **不推送**、工作树保持原样（不 force、不丢内容）
#
# 用法：sh tests/flight-test.sh          （可在 macOS 上跑；生产镜像里有 flock）
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(dirname "$HERE")"
export MERGE_LOGSEQ_AWK="$PKG/merge-logseq.awk"
DRIVER="$PKG/merge-logseq.sh"
WORK="$(mktemp -d)"
FAILED=0

cleanup() { [ -n "${SYNC_PID:-}" ] && kill "$SYNC_PID" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

pass() { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; FAILED=$((FAILED + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1（期望 [$3] 实际 [$2]）"; fi; }

git_init() { git -c init.defaultBranch=main init -q "$1"; }
commit_all() {
  git -C "$1" add -A
  git -C "$1" -c user.name=t -c user.email=t@t commit -q -m "${2:-change}"
}

# 与 sync.sh 相同的驱动注册方式（.git 下，不动 graph 仓）
# 与 sync.sh 相同的驱动注册方式（.git 下，不动 graph 仓）；
# 第二个参数指定冲突标记风格：驱动必须同时兼容 merge（容器默认）与 zdiff3（本机全局）
configure_driver() {
  git -C "$1" config merge.logseq.name "union merge for Logseq markdown"
  git -C "$1" config merge.logseq.driver "$DRIVER %O %A %B"
  git -C "$1" config merge.conflictStyle "${2:-merge}"
  mkdir -p "$1/.git/info"
  printf '%s\n' '*.md merge=logseq' > "$1/.git/info/attributes"
}

ORIGIN="$WORK/origin.git"
git init -q --bare --initial-branch=main "$ORIGIN"
SEED="$WORK/seed"
git clone -q "$ORIGIN" "$SEED"
mkdir -p "$SEED/journals"
printf '%s\n' '- [[活动日志]]' > "$SEED/journals/2026_10_08.md"
commit_all "$SEED" seed
git -C "$SEED" push -q origin main

echo "① 两边各追加不同条目（merge 风格标记）→ 并集合并保留双方"
A="$WORK/a"; B="$WORK/b"
git clone -q "$ORIGIN" "$A"; git clone -q "$ORIGIN" "$B"
configure_driver "$A" merge; configure_driver "$B" merge
L1='- 21:00 [[github.com/acme/one]] 甲设备看到一篇'
L2='- 21:01 [[github.com/acme/two]] 乙设备转发另一篇'
printf '%s\n' "$L1" >> "$A/journals/2026_10_08.md"; commit_all "$A" a
printf '%s\n' "$L2" >> "$B/journals/2026_10_08.md"; commit_all "$B" b
git -C "$A" push -q origin main
if git -C "$B" pull -q --no-rebase origin main 2>"$WORK/b-merge.err"; then
  pass "B 的 merge 干净成功（驱动已并集化冲突）"
else
  fail "B 的 merge 失败：$(cat "$WORK/b-merge.err")"
fi
MERGED="$(cat "$B/journals/2026_10_08.md")"
case "$MERGED" in *"$L1"*) pass "甲的条目还在" ;; *) fail "甲的条目丢了：$MERGED" ;; esac
case "$MERGED" in *"$L2"*) pass "乙的条目还在" ;; *) fail "乙的条目丢了：$MERGED" ;; esac
case "$MERGED" in *'<<<<<<<'*|*'>>>>>>>'*) fail "留下了冲突标记" ;; *) pass "没有冲突标记" ;; esac
check "段位头只留一份（未重复）" "$(grep -c '\[\[活动日志\]\]' "$B/journals/2026_10_08.md")" "1"
git -C "$B" push -q origin main && pass "并集后可以推送" || fail "并集后推送失败"

echo
echo "② 两边写完全相同的行（zdiff3 风格标记）→ 去重只留一份"
C="$WORK/c"; D="$WORK/d"
git clone -q "$ORIGIN" "$C"; git clone -q "$ORIGIN" "$D"
configure_driver "$C" zdiff3; configure_driver "$D" zdiff3
SAME='- 22:00 两边都记了这一条'
printf '%s\n' "$SAME" >> "$C/journals/2026_10_08.md"; commit_all "$C" dup-a
printf '%s\n' "$SAME" >> "$D/journals/2026_10_08.md"; commit_all "$D" dup-b
git -C "$C" push -q origin main
git -C "$D" pull -q --no-rebase origin main
check "相同行只出现一次" "$(grep -c -F -e "$SAME" "$D/journals/2026_10_08.md")" "1"

echo
echo "③ 结构性可疑的冲突 → 驱动 fail-closed"
BASE_F="$WORK/base.md"; OURS_F="$WORK/ours.md"; THEIRS_F="$WORK/theirs.md"
printf '%s\n' '- [[活动日志]]' '- 旧的' > "$BASE_F"
printf '%s\n' '- [[活动日志]]' '- 我们的块' > "$OURS_F"
printf '%s\n' '- [[活动日志]]' '**粗体不是块行** 别人改的' > "$THEIRS_F"
if sh "$DRIVER" "$BASE_F" "$OURS_F" "$THEIRS_F" 2>"$WORK/driver.err"; then
  fail "结构可疑的冲突竟然被「解决」了（会静默丢内容）"
else
  pass "驱动拒绝了结构可疑的冲突（非 0 退出）"
fi
case "$(cat "$OURS_F")" in
  *'<<<<<<<'*) pass "保留了冲突标记交人工处理" ;;
  *) fail "冲突标记被吞掉了：$(cat "$OURS_F")" ;;
esac

echo
echo "④ sync.sh 真跑一轮：本地改动 → commit → push"
E="$WORK/e"
git clone -q "$ORIGIN" "$E"
BEFORE="$(git -C "$ORIGIN" rev-parse main)"
printf '%s\n' '- 23:00 API 写出来的条目' >> "$E/journals/2026_10_08.md"
REPO_URL="$ORIGIN" BRANCH=main DEST="$E" INTERVAL_SECONDS=3 GIT_SYNC_PUSH=1 \
  sh "$PKG/sync.sh" >"$WORK/sync-e.log" 2>&1 &
SYNC_PID=$!
# 轮询而不是死等：本机 git 每次调用约 1s，固定 sleep 太脆
i=0
AFTER="$BEFORE"
while [ "$i" -lt 40 ]; do
  AFTER="$(git -C "$ORIGIN" rev-parse main)"
  [ "$AFTER" != "$BEFORE" ] && break
  i=$((i + 1))
  sleep 1
done
kill "$SYNC_PID" 2>/dev/null || true
wait "$SYNC_PID" 2>/dev/null || true
SYNC_PID=""
if [ "$BEFORE" != "$AFTER" ]; then
  pass "远端 HEAD 前进了（$BEFORE → ${AFTER}）"
else
  fail "远端 HEAD 没变，改动没推出去：$(tail -n 5 "$WORK/sync-e.log")"
fi
if git -C "$ORIGIN" show "main:journals/2026_10_08.md" | grep -q 'API 写出来的条目'; then
  pass "远端真的收到了那一条"
else
  fail "远端内容里没有那条改动"
fi
check "sync.sh 注册了并集驱动" "$(git -C "$E" config merge.logseq.driver | grep -c merge-logseq.sh)" "1"
[ -f "$E/.git/logseq-write.lock" ] && pass "用了与 API 约定的锁文件" || fail "锁文件没建立"
if grep -q '.*.tmp-\*' "$E/.git/info/exclude" && grep -q 'logseq-write.lock' "$E/.git/info/exclude"; then
  pass "中间产物（临时文件/锁）已排除出版本控制"
else
  fail ".git/info/exclude 没写全：$(cat "$E/.git/info/exclude")"
fi
if grep -q 'WARN: 本机没有 flock' "$WORK/sync-e.log"; then
  echo "  NOTE  本机无 flock（macOS），已显式告警——容器里会走真锁"
fi

echo
echo "⑤ 冲突并集不掉时 sync.sh 不推送"
F="$WORK/f"
git clone -q "$ORIGIN" "$F"
configure_driver "$F" zdiff3
# 制造「结构性冲突」：远端把同一行改成粗体（非块行），本地改成块行
REMOTE_TMP="$WORK/remote-tmp"
git clone -q "$ORIGIN" "$REMOTE_TMP"
sed -i.bak 's/^- \[\[活动日志\]\]$/**F 的别人改法**/' "$REMOTE_TMP/journals/2026_10_08.md"
rm -f "$REMOTE_TMP/journals/2026_10_08.md.bak"
commit_all "$REMOTE_TMP" structural-remote
git -C "$REMOTE_TMP" push -q origin main
sed -i.bak 's/^- \[\[活动日志\]\]$/- [[活动日志]] 本地改法/' "$F/journals/2026_10_08.md"
rm -f "$F/journals/2026_10_08.md.bak"
commit_all "$F" structural-local
ORIGIN_BEFORE_CONFLICT="$(git -C "$ORIGIN" rev-parse main)"
if git -C "$F" pull -q --no-rebase origin main 2>"$WORK/f-merge.err"; then
  fail "结构性冲突竟然合并成功了"
else
  pass "结构性冲突被判定为未解决"
fi
check "未解决冲突时远端没被推送" "$(git -C "$ORIGIN" rev-parse main)" "$ORIGIN_BEFORE_CONFLICT"
case "$(cat "$F/journals/2026_10_08.md")" in
  *'<<<<<<<'*) pass "本地工作树保留冲突标记，等人工处理" ;;
  *) fail "本地冲突标记被吞：$(cat "$F/journals/2026_10_08.md")" ;;
esac

echo
if [ "$FAILED" -eq 0 ]; then echo "全部通过"; else echo "失败 $FAILED 项"; fi
exit "$FAILED"
