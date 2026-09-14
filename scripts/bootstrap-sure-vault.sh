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

APP_PATH="${APP_PATH:-kv/k8s/tools/finance/sure/app}"
DB_PATH="${DB_PATH:-kv/k8s/tools/finance/sure/db}"
OIDC_PATH="${OIDC_PATH:-kv/k8s/tools/finance/sure/oidc}"

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

POSTGRES_USER="${POSTGRES_USER:-sure}"
POSTGRES_DB="${POSTGRES_DB:-sure}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(existing_or_generated "$DB_PATH" POSTGRES_PASSWORD openssl rand -hex 24)}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(existing_or_generated "$DB_PATH" REDIS_PASSWORD openssl rand -hex 24)}"
SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(existing_or_generated "$APP_PATH" SECRET_KEY_BASE openssl rand -hex 64)}"
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY="${ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY:-$(existing_or_generated "$APP_PATH" ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY openssl rand -hex 32)}"
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY="${ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY:-$(existing_or_generated "$APP_PATH" ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY openssl rand -hex 32)}"
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="${ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT:-$(existing_or_generated "$APP_PATH" ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT openssl rand -hex 32)}"
OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-$(existing_or_generated "$OIDC_PATH" OIDC_CLIENT_ID sh -c 'printf "sure-%s" "$(openssl rand -hex 12)"')}"
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-$(existing_or_generated "$OIDC_PATH" OIDC_CLIENT_SECRET openssl rand -base64 48 | tr -d '\n')}"
OIDC_ISSUER="${OIDC_ISSUER:-https://auth.nserbin.com/application/o/sure/}"
OIDC_REDIRECT_URI="${OIDC_REDIRECT_URI:-https://money.nserbin.com/auth/openid_connect/callback}"

vault kv put "${DB_PATH}" \
  POSTGRES_USER="${POSTGRES_USER}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  POSTGRES_DB="${POSTGRES_DB}" \
  REDIS_PASSWORD="${REDIS_PASSWORD}" >/dev/null

vault kv put "${APP_PATH}" \
  SECRET_KEY_BASE="${SECRET_KEY_BASE}" \
  ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY="${ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY}" \
  ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY="${ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY}" \
  ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="${ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT}" >/dev/null

vault kv put "${OIDC_PATH}" \
  OIDC_CLIENT_ID="${OIDC_CLIENT_ID}" \
  OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET}" \
  OIDC_ISSUER="${OIDC_ISSUER}" \
  OIDC_REDIRECT_URI="${OIDC_REDIRECT_URI}" >/dev/null

echo "Sure Vault bootstrap complete:"
echo "- ${APP_PATH}"
echo "- ${DB_PATH}"
echo "- ${OIDC_PATH}"
