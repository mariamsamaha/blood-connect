FROM nginx:1.27-alpine

RUN apk add --no-cache openssl

COPY nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/key.pem \
        -out    /etc/nginx/ssl/cert.pem \
        -days 365 -nodes \
        -subj "/CN=localhost/O=BloodConnect/C=EG" 2>/dev/null

EXPOSE 80 443

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost/health | grep -q '"status":"ok"' || exit 1

CMD ["nginx", "-g", "daemon off;"]
