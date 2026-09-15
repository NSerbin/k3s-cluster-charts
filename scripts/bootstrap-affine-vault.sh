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

APP_PATH="${APP_PATH:-kv/k8s/tools/documents/affine/app}"
DB_PATH="${DB_PATH:-kv/k8s/tools/documents/affine/db}"
REDIS_PATH="${REDIS_PATH:-kv/k8s/tools/documents/affine/redis}"
OIDC_PATH="${OIDC_PATH:-kv/k8s/tools/documents/affine/oidc}"

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

generate_affine_private_key() {
  openssl ecparam -name prime256v1 -genkey -noout \
    | openssl pkcs8 -topk8 -nocrypt
}

POSTGRES_USER="${POSTGRES_USER:-affine}"
POSTGRES_DB="${POSTGRES_DB:-affine}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(existing_or_generated "$DB_PATH" POSTGRES_PASSWORD openssl rand -hex 24)}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(existing_or_generated "$REDIS_PATH" REDIS_PASSWORD openssl rand -hex 24)}"
AFFINE_PRIVATE_KEY="${AFFINE_PRIVATE_KEY:-$(existing_or_generated "$APP_PATH" AFFINE_PRIVATE_KEY generate_affine_private_key)}"

OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-$(existing_or_generated "$OIDC_PATH" OIDC_CLIENT_ID sh -c 'printf "affine-%s" "$(openssl rand -hex 12)"')}"
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-$(existing_or_generated "$OIDC_PATH" OIDC_CLIENT_SECRET openssl rand -base64 48 | tr -d '\n')}"
OIDC_ISSUER="${OIDC_ISSUER:-https://auth.nserbin.com/application/o/affine/}"
OIDC_DISCOVERY_URL="${OIDC_DISCOVERY_URL:-https://auth.nserbin.com/application/o/affine/.well-known/openid-configuration}"

vault kv put "${DB_PATH}" \
  POSTGRES_USER="${POSTGRES_USER}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  POSTGRES_DB="${POSTGRES_DB}" >/dev/null

vault kv put "${REDIS_PATH}" \
  REDIS_PASSWORD="${REDIS_PASSWORD}" >/dev/null

vault kv put "${APP_PATH}" \
  AFFINE_PRIVATE_KEY="${AFFINE_PRIVATE_KEY}" >/dev/null

vault kv put "${OIDC_PATH}" \
  OIDC_CLIENT_ID="${OIDC_CLIENT_ID}" \
  OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET}" \
  OIDC_ISSUER="${OIDC_ISSUER}" \
  OIDC_DISCOVERY_URL="${OIDC_DISCOVERY_URL}" >/dev/null

echo "AFFiNE Vault bootstrap complete:"
echo "- ${APP_PATH}"
echo "- ${DB_PATH}"
echo "- ${REDIS_PATH}"
echo "- ${OIDC_PATH}"
