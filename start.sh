#!/bin/bash

mkdir -p logs
touch logs/error.log

mkdir -p cache

sudo /usr/local/openresty/nginx/sbin/nginx -p "$(pwd)" -c "nginx.conf"
