# 冲突区域做「行多重集并集」。输入：git merge-file 产出的带冲突标记的合并结果。
#
#   每行取 max(ours 份数, theirs 份数)：先按 ours 顺序输出，再补 theirs 独有的行。
#   两边各追加不同条目 → 都在；两边写了完全相同的行 → 只留一行。
#
# **两种冲突标记风格都要认**（实测：本机全局 `merge.conflictStyle=diff3` 时，驱动拿到的
# 输入会多出 `||||||| base` 段；只认普通风格会把 base 段错当成 ours）：
#     <<<<<<< ours / [ours 行] / ||||||| base / [base 行] / ======= / [theirs 行] / >>>>>>> theirs
#
# 不敢猜就 fail-closed：冲突区里出现不是「块行（`-`）/ 续行（tab/空格）/ 空行」的行，
# 或冲突区大得离谱 → 退出码 3，调用方保留冲突标记、停止推送、等人工处理。
# 宁可停在冲突上，也不静默丢内容。
BEGIN { state = 0; ok = 1; MAXREGION = 20000 }

function max2(a, b) { return a > b ? a : b }

function plausible(line) {
  if (line == "") return 1
  c = substr(line, 1, 1)
  return (c == "-" || c == "\t" || c == " ") ? 1 : 0
}

function reset_region() {
  ours_n = 0
  theirs_n = 0
  for (k in cnt_o) delete cnt_o[k]
  for (k in cnt_t) delete cnt_t[k]
  for (k in need) delete need[k]
  for (k in emitted) delete emitted[k]
}

function resolve(   i, k, line) {
  for (i = 1; i <= ours_n; i++) if (!plausible(ours[i])) { ok = 0; return }
  for (i = 1; i <= theirs_n; i++) if (!plausible(theirs[i])) { ok = 0; return }

  for (i = 1; i <= ours_n; i++) cnt_o[ours[i]]++
  for (i = 1; i <= theirs_n; i++) cnt_t[theirs[i]]++

  for (k in cnt_o) need[k] = cnt_o[k]
  for (k in cnt_t) need[k] = max2(need[k], cnt_t[k])

  for (i = 1; i <= ours_n; i++) {
    line = ours[i]
    if (emitted[line] < need[line]) { print line; emitted[line]++ }
  }
  for (i = 1; i <= theirs_n; i++) {
    line = theirs[i]
    if (emitted[line] < need[line]) { print line; emitted[line]++ }
  }
}

# 冲突区外：原样输出（`<<<<<<<` 之前的正常内容）
state == 0 {
  if ($0 ~ /^<<<<<<< /) { reset_region(); state = 1; next }
  print
  next
}

# ours 段：到 `|||||||`（diff3 的 base 段）或 `=======` 结束
state == 1 {
  if ($0 ~ /^\|\|\|\|\|\|\| /) { state = 2; next }
  if ($0 ~ /^=======$/) { state = 3; next }
  ours[++ours_n] = $0
  if (ours_n > MAXREGION) ok = 0
  next
}

# base 段（仅 diff3 风格）：内容丢弃——并集不需要 base
state == 2 {
  if ($0 ~ /^=======$/) { state = 3; next }
  next
}

# theirs 段：到 `>>>>>>>` 结束 → 立刻并集化
state == 3 {
  if ($0 ~ /^>>>>>>> /) { resolve(); state = 0; next }
  theirs[++theirs_n] = $0
  if (theirs_n > MAXREGION) ok = 0
  next
}

END { if (state != 0 || !ok) exit 3 }
