#!/bin/sh
set -eu

cd "$(dirname "$0")"
/usr/bin/docker compose -f compose.certbot.yml run --rm certbot renew --quiet
/usr/sbin/nginx -t
/usr/bin/systemctl reload nginx
