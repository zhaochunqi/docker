FROM python:3.15-slim-bookworm@sha256:96599df822d0e1c6bb700014a05c7f3c8cabc6e0f7ff3c4f9f69cee033b4b5d9

# tini 作为 init 进程，确保信号（SIGTERM）能正确传递给子进程，容器可以干净退出
RUN apt-get update && apt-get install -y --no-install-recommends tini \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir cryptography

COPY cleanup_certs.py /cleanup_certs.py

ENTRYPOINT ["/usr/bin/tini", "--", "python3", "/cleanup_certs.py"]
CMD ["/data/acme.json"]
