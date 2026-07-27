FROM python:3.14-slim-bookworm AS builder

RUN pip install --no-cache-dir cryptography

FROM python:3.14-slim-bookworm

# tini 作为 init 进程，确保信号（SIGTERM）能正确传递给子进程，容器可以干净退出
RUN apt-get update && apt-get install -y --no-install-recommends tini \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY cleanup_certs.py /cleanup_certs.py

ENTRYPOINT ["/usr/bin/tini", "--", "python3", "/cleanup_certs.py"]
CMD ["/data/acme.json"]

