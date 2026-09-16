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

APP_PATH="${APP_PATH:-kv/k8s/tools/knowledge/colanode/app}"

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

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-colanode}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(existing_or_generated "$APP_PATH" POSTGRES_PASSWORD openssl rand -hex 24)}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(existing_or_generated "$APP_PATH" REDIS_PASSWORD openssl rand -hex 24)}"

POSTGRES_URL="${POSTGRES_URL:-postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@colanode-postgres:5432/${POSTGRES_DB}}"
REDIS_URL="${REDIS_URL:-redis://:${REDIS_PASSWORD}@colanode-redis:6379/0}"

vault kv put "${APP_PATH}" \
  POSTGRES_USER="${POSTGRES_USER}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  POSTGRES_DB="${POSTGRES_DB}" \
  POSTGRES_URL="${POSTGRES_URL}" \
  REDIS_PASSWORD="${REDIS_PASSWORD}" \
  REDIS_URL="${REDIS_URL}" >/dev/null

echo "Colanode Vault bootstrap complete:"
echo "- ${APP_PATH}"
