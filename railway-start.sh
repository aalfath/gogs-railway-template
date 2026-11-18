#!/bin/sh
# Railway wrapper for the official Gogs image.
# 1. Writes /data/gogs/conf/app.ini from the environment on every start, so
#    the install wizard never opens and the config follows the variables.
# 2. On the first start, creates the admin account once Gogs answers.
# 3. Hands over to the image's entrypoint (Gogs + OpenSSH under s6).
set -e

CONF_DIR=/data/gogs/conf
CONF="$CONF_DIR/app.ini"
MARKER=/data/gogs/.railway-admin-created
PORT="${PORT:-3000}"

fail() { echo "railway-start: $*" >&2; exit 1; }

[ -n "$GOGS_SECRET_KEY" ] || fail "GOGS_SECRET_KEY is not set. Use \${{secret(32)}}."
[ -n "$GOGS_DB_HOST" ] || fail "GOGS_DB_HOST is not set. Point it at Postgres, e.g. \${{Postgres.PGHOST}}:\${{Postgres.PGPORT}}."

# Public URL: GOGS_EXTERNAL_URL wins (custom domains), else the Railway domain.
if [ -n "$GOGS_EXTERNAL_URL" ]; then
  EXTERNAL_URL="${GOGS_EXTERNAL_URL%/}/"
elif [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  EXTERNAL_URL="https://$RAILWAY_PUBLIC_DOMAIN/"
else
  EXTERNAL_URL="http://localhost:$PORT/"
fi
DOMAIN=$(echo "$EXTERNAL_URL" | sed -E 's#^[a-z]+://([^/:]+).*#\1#')
case "$EXTERNAL_URL" in https://*) SECURE=true ;; *) SECURE=false ;; esac

# Git over SSH: on when the service has a Railway TCP proxy to port 22.
SSH_DOMAIN="${GOGS_SSH_DOMAIN:-$RAILWAY_TCP_PROXY_DOMAIN}"
SSH_PORT="${GOGS_SSH_PORT:-$RAILWAY_TCP_PROXY_PORT}"
if [ -n "$SSH_DOMAIN" ] && [ -n "$SSH_PORT" ]; then DISABLE_SSH=false; else DISABLE_SSH=true; SSH_DOMAIN="$DOMAIN"; SSH_PORT=22; fi

mkdir -p "$CONF_DIR" /data/gogs/data /data/gogs/log /data/git/gogs-repositories /data/ssh
umask 077
cat > "$CONF.tmp" <<INI
; Written by railway-start.sh on every start. Do not edit: change the
; service variables instead, or add GOGS__<section>__<KEY> variables.
BRAND_NAME = ${GOGS_BRAND_NAME:-Gogs}
RUN_USER = git
RUN_MODE = prod

[server]
EXTERNAL_URL = $EXTERNAL_URL
DOMAIN = $DOMAIN
PROTOCOL = http
HTTP_ADDR = 0.0.0.0
HTTP_PORT = $PORT
LOCAL_ROOT_URL = http://localhost:$PORT/
APP_DATA_PATH = /data/gogs/data
DISABLE_SSH = $DISABLE_SSH
START_SSH_SERVER = false
SSH_DOMAIN = $SSH_DOMAIN
SSH_PORT = $SSH_PORT
OFFLINE_MODE = false

[repository]
ROOT = /data/git/gogs-repositories

[repository.upload]
TEMP_PATH = /data/gogs/data/tmp/uploads

[database]
TYPE = postgres
HOST = $GOGS_DB_HOST
NAME = ${GOGS_DB_NAME:-railway}
USER = ${GOGS_DB_USER:-postgres}
PASSWORD = \`$GOGS_DB_PASSWORD\`
SCHEMA = public
SSL_MODE = ${GOGS_DB_SSL_MODE:-disable}

[security]
INSTALL_LOCK = true
SECRET_KEY = \`$GOGS_SECRET_KEY\`
COOKIE_SECURE = $SECURE

[auth]
DISABLE_REGISTRATION = ${GOGS_DISABLE_REGISTRATION:-true}
REQUIRE_SIGNIN_VIEW = ${GOGS_REQUIRE_SIGNIN_VIEW:-false}

[session]
PROVIDER = file
PROVIDER_CONFIG = /data/gogs/data/sessions
COOKIE_SECURE = $SECURE

[attachment]
PATH = /data/gogs/data/attachments

[lfs]
OBJECTS_PATH = /data/gogs/data/lfs-objects
OBJECTS_TEMP_PATH = /data/gogs/data/tmp/lfs-objects

[picture]
AVATAR_UPLOAD_PATH = /data/gogs/data/avatars
REPOSITORY_AVATAR_UPLOAD_PATH = /data/gogs/data/repo-avatars

[email]
ENABLED = false

[log]
MODE = console
LEVEL = Info
ROOT_PATH = /data/gogs/log
INI

# Extra settings: GOGS__<section>__<KEY>=value (write a dot in a section
# name as _0X2E_, e.g. GOGS__repository_0X2E_upload__FILE_MAX_SIZE=50).
# Later lines win, so these override the defaults above.
env | grep '^GOGS__' | sort | while IFS='=' read -r name value; do
  rest=${name#GOGS__}
  section=$(echo "${rest%%__*}" | sed 's/_0X2E_/./g' | tr 'A-Z' 'a-z')
  key=${rest#*__}
  [ -n "$section" ] && [ -n "$key" ] && [ "$key" != "$rest" ] || continue
  printf '\n[%s]\n%s = %s\n' "$section" "$key" "$value"
done >> "$CONF.tmp"
mv "$CONF.tmp" "$CONF"
umask 022
chown -R 1000:1000 /data/gogs/conf 2>/dev/null || true

# First start: create the admin once the web server answers.
if [ ! -f "$MARKER" ] && [ -n "$GOGS_ADMIN_PASSWORD" ]; then
  ADMIN_USER="${GOGS_ADMIN_USERNAME:-owner}"
  ADMIN_EMAIL="${GOGS_ADMIN_EMAIL:-$ADMIN_USER@$DOMAIN}"
  (
    i=0
    until curl -fsS -o /dev/null "http://localhost:$PORT/healthcheck"; do
      i=$((i + 1)); [ $i -gt 150 ] && { echo "railway-start: Gogs did not answer, admin not created" >&2; exit 0; }
      sleep 2
    done
    if out=$(gosu git /app/gogs/gogs admin create-user --config "$CONF" \
        --name "$ADMIN_USER" --password "$GOGS_ADMIN_PASSWORD" --email "$ADMIN_EMAIL" --admin 2>&1); then
      echo "railway-start: created admin account \"$ADMIN_USER\" (password: the GOGS_ADMIN_PASSWORD variable)"
      touch "$MARKER"
    elif echo "$out" | grep -qi 'already exist'; then
      echo "railway-start: admin account \"$ADMIN_USER\" already exists"
      touch "$MARKER"
    else
      echo "railway-start: could not create the admin account: $out" >&2
    fi
  ) &
fi

exec /app/gogs/docker/start.sh "$@"
