FROM nginx:1.27.3-alpine

RUN apk add --no-cache gettext curl

COPY config/nginx.conf.template /etc/nginx/nginx.conf.template
COPY scripts/entrypoint.sh /entrypoint.sh
COPY src/html/ /usr/share/nginx/html/

RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html && \
    mkdir -p /tmp/cache/nginx/client_temp /tmp/cache/nginx/proxy_temp /tmp/cache/nginx/fastcgi_temp /tmp/cache/nginx/uwsgi_temp /tmp/cache/nginx/scgi_temp && \
    chown -R nginx:nginx /tmp && \
    chmod +x /entrypoint.sh

ENV NGINX_PORT=8080
ENV NGINX_SERVER_NAME="localhost"
ENV NGINX_WORKER_CONNECTIONS=1024

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${NGINX_PORT}/health || exit 1

EXPOSE ${NGINX_PORT}

USER nginx

ENTRYPOINT ["/entrypoint.sh"]