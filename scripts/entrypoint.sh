#!/bin/sh

export NGINX_PORT=${NGINX_PORT:-8080}
export NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-1024}

# Build NGINX_SERVER_NAME from domain variables
if [ -n "$DOMAIN_1" ] || [ -n "$DOMAIN_2" ] || [ -n "$DOMAIN_3" ]; then
    NGINX_SERVER_NAME=""
    [ -n "$DOMAIN_1" ] && NGINX_SERVER_NAME="$DOMAIN_1"
    [ -n "$DOMAIN_2" ] && NGINX_SERVER_NAME="$NGINX_SERVER_NAME $DOMAIN_2"
    [ -n "$DOMAIN_3" ] && NGINX_SERVER_NAME="$NGINX_SERVER_NAME $DOMAIN_3"
    # Remove leading space if any
    NGINX_SERVER_NAME=$(echo "$NGINX_SERVER_NAME" | sed 's/^ *//')
fi
NGINX_SERVER_NAME=${NGINX_SERVER_NAME:-"localhost"}

export NGINX_SERVER_NAME

envsubst '${NGINX_PORT} ${NGINX_SERVER_NAME} ${NGINX_WORKER_CONNECTIONS}' < /etc/nginx/nginx.conf.template > /tmp/nginx.conf

exec nginx -c /tmp/nginx.conf -g 'daemon off;'