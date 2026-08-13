# git-sync：周期拉取远端 git 仓库到本地工作树（只读）。
# 第一步只读：git clone 后循环 fetch + merge --ff-only，工作树永远对齐远端分支。
# 后续启用写回时，在同一循环内扩展 rebase + push。
# 底座用 debian-slim（不用 alpine，规避网络兼容问题）。
FROM debian:bookworm-slim

# tini 作为 init 进程，确保 SIGTERM 正确转发给脚本，容器可干净退出
RUN apt-get update && apt-get install -y --no-install-recommends tini git ca-certificates openssh-client \
    && rm -rf /var/lib/apt/lists/*

COPY sync.sh /sync.sh
RUN chmod +x /sync.sh

ENV REPO_URL="" \
    BRANCH="main" \
    INTERVAL_SECONDS="60" \
    DEST="/repo"

ENTRYPOINT ["/usr/bin/tini", "--", "/sync.sh"]
