#!/bin/sh

set -e

if [ -z "$BACKEND_URL" ]; then
    echo "ERROR: BACKEND_URL is not set"
    exit 1
fi

echo "Configuring backend URL: $BACKEND_URL"

sed -i "s|BACKEND_URL_PLACEHOLDER|${BACKEND_URL}|g" \
    /etc/nginx/conf.d/default.conf
