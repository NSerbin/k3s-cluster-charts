#!/usr/bin/env bash
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need jq
need openssl
need vault

APP_PATH="${APP_PATH:-kv/k8s/tools/productivity/cal-diy/app}"
DB_PATH="${DB_PATH:-kv/k8s/tools/productivity/cal-diy/db}"

existing_or_generated() {
  local path="$1"
  local key="$2"
  shift 2

  local current
  current="$(vault kv get -format=json "$path" 2>/dev/null | jq -r --arg key "$key" '.data.data[$key] // empty' || true)"
  if [ -n "$current" ]; then
    printf '%s' "$current"
    return
  fi

  "$@"
}

POSTGRES_USER="${POSTGRES_USER:-cal_diy}"
POSTGRES_DB="${POSTGRES_DB:-caldiy}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(existing_or_generated "$DB_PATH" POSTGRES_PASSWORD openssl rand -hex 24)}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(existing_or_generated "$DB_PATH" REDIS_PASSWORD openssl rand -hex 24)}"

NEXTAUTH_SECRET="${NEXTAUTH_SECRET:-$(existing_or_generated "$APP_PATH" NEXTAUTH_SECRET openssl rand -base64 32 | tr -d '\n')}"
CALENDSO_ENCRYPTION_KEY="${CALENDSO_ENCRYPTION_KEY:-$(existing_or_generated "$APP_PATH" CALENDSO_ENCRYPTION_KEY openssl rand -base64 24 | tr -d '\n')}"
CRON_API_KEY="${CRON_API_KEY:-$(existing_or_generated "$APP_PATH" CRON_API_KEY openssl rand -hex 24)}"
JWT_SECRET="${JWT_SECRET:-$(existing_or_generated "$APP_PATH" JWT_SECRET openssl rand -base64 32 | tr -d '\n')}"

vault kv put "${DB_PATH}" \
  POSTGRES_USER="${POSTGRES_USER}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  POSTGRES_DB="${POSTGRES_DB}" \
  REDIS_PASSWORD="${REDIS_PASSWORD}" >/dev/null

vault kv put "${APP_PATH}" \
  NEXTAUTH_SECRET="${NEXTAUTH_SECRET}" \
  CALENDSO_ENCRYPTION_KEY="${CALENDSO_ENCRYPTION_KEY}" \
  CRON_API_KEY="${CRON_API_KEY}" \
  JWT_SECRET="${JWT_SECRET}" >/dev/null

echo "Cal.diy Vault bootstrap complete:"
echo "- ${APP_PATH}"
echo "- ${DB_PATH}"
