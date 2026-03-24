FROM quay.io/outline/shadowbox:stable

RUN apk add --no-cache openssl

COPY scripts/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
