FROM alpine:3.19

RUN apk add --no-cache python3 py3-pip && \
    pip install --no-cache-dir cryptography --break-system-packages

COPY cleanup_certs.py /cleanup_certs.py

ENTRYPOINT ["python3", "/cleanup_certs.py"]
CMD ["/data/acme.json"]

