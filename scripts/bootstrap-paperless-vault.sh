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

APP_PATH="${APP_PATH:-kv/k8s/tools/documents/paperless/app}"
DB_PATH="${DB_PATH:-kv/k8s/tools/documents/paperless/db}"
OIDC_PATH="${OIDC_PATH:-kv/k8s/tools/documents/paperless/oidc}"

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

POSTGRES_USER="${POSTGRES_USER:-paperless}"
POSTGRES_DB="${POSTGRES_DB:-paperless}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-$(existing_or_generated "$DB_PATH" POSTGRES_PASSWORD openssl rand -hex 24)}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(existing_or_generated "$DB_PATH" REDIS_PASSWORD openssl rand -hex 24)}"

PAPERLESS_SECRET_KEY="${PAPERLESS_SECRET_KEY:-$(existing_or_generated "$APP_PATH" PAPERLESS_SECRET_KEY openssl rand -base64 64 | tr -d '\n')}"
PAPERLESS_ADMIN_USER="${PAPERLESS_ADMIN_USER:-nicolas}"
PAPERLESS_ADMIN_MAIL="${PAPERLESS_ADMIN_MAIL:-nicolas.serbin@gmail.com}"
PAPERLESS_ADMIN_PASSWORD="${PAPERLESS_ADMIN_PASSWORD:-$(existing_or_generated "$APP_PATH" PAPERLESS_ADMIN_PASSWORD openssl rand -base64 32 | tr -d '\n')}"

OIDC_CLIENT_ID="${OIDC_CLIENT_ID:-$(existing_or_generated "$OIDC_PATH" OIDC_CLIENT_ID sh -c 'printf "paperless-%s" "$(openssl rand -hex 12)"')}"
OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET:-$(existing_or_generated "$OIDC_PATH" OIDC_CLIENT_SECRET openssl rand -base64 48 | tr -d '\n')}"
OIDC_DISCOVERY_URL="${OIDC_DISCOVERY_URL:-https://auth.nserbin.com/application/o/paperless/.well-known/openid-configuration}"
PAPERLESS_SOCIALACCOUNT_PROVIDERS="$(
  jq -cn \
    --arg client_id "$OIDC_CLIENT_ID" \
    --arg secret "$OIDC_CLIENT_SECRET" \
    --arg server_url "$OIDC_DISCOVERY_URL" \
    '{
    openid_connect: {
      OAUTH_PKCE_ENABLED: true,
      EMAIL_AUTHENTICATION: true,
      VERIFIED_EMAIL: true,
      APPS: [{
        provider_id: "authentik",
        name: "authentik",
        client_id: $client_id,
        secret: $secret,
        settings: {
          server_url: $server_url,
          fetch_userinfo: true,
          email_authentication: true,
          verified_email: true
        }
      }],
      SCOPE: ["openid", "profile", "email"]
      }
    }'
)"

vault kv put "${DB_PATH}" \
  POSTGRES_USER="${POSTGRES_USER}" \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  POSTGRES_DB="${POSTGRES_DB}" \
  REDIS_PASSWORD="${REDIS_PASSWORD}" >/dev/null

vault kv put "${APP_PATH}" \
  PAPERLESS_SECRET_KEY="${PAPERLESS_SECRET_KEY}" \
  PAPERLESS_ADMIN_USER="${PAPERLESS_ADMIN_USER}" \
  PAPERLESS_ADMIN_PASSWORD="${PAPERLESS_ADMIN_PASSWORD}" \
  PAPERLESS_ADMIN_MAIL="${PAPERLESS_ADMIN_MAIL}" \
  PAPERLESS_SOCIALACCOUNT_PROVIDERS="${PAPERLESS_SOCIALACCOUNT_PROVIDERS}" >/dev/null

vault kv put "${OIDC_PATH}" \
  OIDC_CLIENT_ID="${OIDC_CLIENT_ID}" \
  OIDC_CLIENT_SECRET="${OIDC_CLIENT_SECRET}" \
  OIDC_DISCOVERY_URL="${OIDC_DISCOVERY_URL}" >/dev/null

echo "Paperless-ngx Vault bootstrap complete:"
echo "- ${APP_PATH}"
echo "- ${DB_PATH}"
echo "- ${OIDC_PATH}"
