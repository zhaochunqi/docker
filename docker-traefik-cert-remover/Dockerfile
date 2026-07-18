FROM python:3.11-slim-bookworm AS builder

COPY cleanup_certs.py /cleanup_certs.py
RUN pip install --no-cache-dir cryptography

FROM gcr.io/distroless/python3-debian12

COPY --from=builder /cleanup_certs.py /cleanup_certs.py
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/dist-packages

ENTRYPOINT ["python3", "/cleanup_certs.py"]
CMD ["/data/acme.json"]

