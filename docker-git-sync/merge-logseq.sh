#!/bin/sh
# git merge driver：Logseq markdown 的「行多重集并集」合并。
#
# 由 .git/info/attributes 的 `*.md merge=logseq` + `merge.logseq.driver` 调用：
#   merge-logseq.sh %O %A %B      # %O=base  %A=ours(就地写结果)  %B=theirs
#
# 为什么不能用默认合并：journal 是**追加型**文件，两台设备各自往同一天日记的同一个段位下
# 追加一行时，git 判为同一区域冲突；对追加型数据，正确语义是**并集**（两边条目都要在），
# 而不是选一边。冲突判定与并集规则见 merge-logseq.awk 头部注释。
#
# 退出码：0 = 已安全合并（调用方继续 merge/push）；非 0 = 保留冲突标记，git 标记该文件未解决，
# sync.sh 随即停止推送并报警。**不 force、不 checkout --ours/--theirs**（那会静默丢内容）。
set -eu

BASE="$1"
OURS="$2"
THEIRS="$3"
# awk helper 路径可覆盖：镜像里是 /merge-logseq.awk，本地飞行测试指向仓库里的那份。
AWK_HELPER="${MERGE_LOGSEQ_AWK:-/merge-logseq.awk}"

if git merge-file -L ours -L base -L theirs "$OURS" "$BASE" "$THEIRS"; then
  exit 0
fi

if ! grep -q '^<<<<<<< ' "$OURS" 2>/dev/null; then
  # merge-file 失败但不是冲突（例如二进制/权限），交给 git 判定，别在这里乱改
  exit 0
fi

if awk -f "$AWK_HELPER" "$OURS" > "$OURS.merged"; then
  mv "$OURS.merged" "$OURS"
  exit 0
fi

rm -f "$OURS.merged"
echo "[merge-logseq] 冲突区无法安全并集（结构可疑或过大），保留冲突标记交人工处理: $OURS" >&2
exit 1
