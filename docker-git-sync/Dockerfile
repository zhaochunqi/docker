# git-sync：周期拉取远端 git 仓库到本地工作树，并把本地改动（logseq-graph-api 写出来的）
# commit & push 回去。与 logseq-graph-api 用同一个 flock 写锁文件互斥；markdown 冲突走
# 并集合合并驱动（merge-logseq.sh），并集不掉就停下不推（fail-closed）。
# 底座用 debian-slim（不用 alpine，规避网络兼容问题）；flock 来自 util-linux、awk 是 mawk，都在 base 里。
FROM debian:bookworm-slim

# tini 作为 init 进程，确保 SIGTERM 正确转发给脚本，容器可干净退出
RUN apt-get update && apt-get install -y --no-install-recommends tini git ca-certificates openssh-client \
    && rm -rf /var/lib/apt/lists/*

COPY sync.sh /sync.sh
COPY merge-logseq.sh /merge-logseq.sh
COPY merge-logseq.awk /merge-logseq.awk
RUN chmod +x /sync.sh /merge-logseq.sh /merge-logseq.awk

ENV REPO_URL="" \
    BRANCH="main" \
    INTERVAL_SECONDS="600" \
    DEST="/repo" \
    GIT_SYNC_PUSH="1" \
    GIT_SYNC_LOCK_WAIT="60"

ENTRYPOINT ["/usr/bin/tini", "--", "/sync.sh"]
