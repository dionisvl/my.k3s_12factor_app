#!/bin/sh

export NGINX_PORT=${NGINX_PORT:-8080}
export NGINX_SERVER_NAME=${NGINX_SERVER_NAME:-"localhost"}
export NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-1024}

envsubst '${NGINX_PORT} ${NGINX_SERVER_NAME} ${NGINX_WORKER_CONNECTIONS}' < /etc/nginx/nginx.conf.template > /tmp/nginx.conf

exec nginx -c /tmp/nginx.conf -g 'daemon off;'