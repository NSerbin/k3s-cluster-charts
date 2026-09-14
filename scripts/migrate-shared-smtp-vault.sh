#!/usr/bin/env bash
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"

NEW_PATH="${NEW_PATH:-kv/k8s/core/tools/emails/smtp}"
SOURCE_NAMESPACE="${SOURCE_NAMESPACE:-tools}"
SOURCE_SECRET="${SOURCE_SECRET:-appflowy-secrets-app}"

read_secret_field() {
  local key="$1"

  kubectl -n "${SOURCE_NAMESPACE}" get secret "${SOURCE_SECRET}" \
    -o jsonpath="{.data.${key}}" \
    | base64 -d
}

SMTP_HOST="$(read_secret_field APPFLOWY_MAILER_SMTP_HOST)"
SMTP_PORT="$(read_secret_field APPFLOWY_MAILER_SMTP_PORT)"
SMTP_FROM="$(read_secret_field APPFLOWY_MAILER_SMTP_EMAIL)"
SMTP_USERNAME="$(read_secret_field APPFLOWY_MAILER_SMTP_USERNAME)"
SMTP_PASSWORD="$(read_secret_field APPFLOWY_MAILER_SMTP_PASSWORD)"

vault kv put "${NEW_PATH}" \
  SMTP_HOST="${SMTP_HOST}" \
  SMTP_PORT="${SMTP_PORT}" \
  SMTP_FROM="${SMTP_FROM}" \
  SMTP_USERNAME="${SMTP_USERNAME}" \
  SMTP_PASSWORD="${SMTP_PASSWORD}" \
  SMTP_SECURITY=starttls \
  SMTP_AUTH_MECHANISM=Login >/dev/null

echo "Shared SMTP secret created at ${NEW_PATH}"
echo "Source: ${SOURCE_NAMESPACE}/${SOURCE_SECRET}"
echo "SMTP host: ${SMTP_HOST}"
echo "SMTP port: ${SMTP_PORT}"
echo "SMTP from: ${SMTP_FROM}"
