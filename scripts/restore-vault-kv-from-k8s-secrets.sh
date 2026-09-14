#!/usr/bin/env bash
set -euo pipefail

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

if ! command -v vault >/dev/null 2>&1; then
  echo "vault CLI is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

: "${VAULT_ADDR:?VAULT_ADDR must be set, example: export VAULT_ADDR=http://127.0.0.1:8200}"

DRY_RUN="${DRY_RUN:-0}"
BACKUP_FILE="${BACKUP_FILE:-$HOME/k8s-secrets-rescue-$(date +%Y%m%d-%H%M%S).yaml}"

echo "==> Checking Vault"
vault status >/dev/null

if ! vault secrets list -format=json | jq -e 'has("kv/")' >/dev/null; then
  echo "==> Enabling kv/ as KV v2"
  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY_RUN: vault secrets enable -path=kv -version=2 kv"
  else
    vault secrets enable -path=kv -version=2 kv
  fi
else
  echo "==> kv/ mount already exists"
fi

echo "==> Saving Kubernetes Secrets rescue backup to: $BACKUP_FILE"
if [ "$DRY_RUN" = "1" ]; then
  echo "DRY_RUN: kubectl get secrets -A -o yaml > \"$BACKUP_FILE\""
else
  kubectl get secrets -A -o yaml > "$BACKUP_FILE"
  chmod 600 "$BACKUP_FILE"
fi

restore_secret() {
  local namespace="$1"
  local secret_name="$2"
  local vault_path="$3"

  if ! kubectl -n "$namespace" get secret "$secret_name" >/dev/null 2>&1; then
    echo "SKIP missing k8s secret: $namespace/$secret_name -> kv/$vault_path"
    return 0
  fi

  local keys
  keys="$(kubectl -n "$namespace" get secret "$secret_name" -o json | jq -r '.data | keys | join(",")')"
  if [ -z "$keys" ] || [ "$keys" = "null" ]; then
    echo "SKIP empty k8s secret: $namespace/$secret_name"
    return 0
  fi

  echo "RESTORE $namespace/$secret_name -> kv/$vault_path [$keys]"

  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi

  kubectl -n "$namespace" get secret "$secret_name" -o json \
    | jq '.data | map_values(@base64d)' \
    | vault kv put "kv/$vault_path" -
}

restore_secret_matching_prefix() {
  local namespace="$1"
  local secret_name="$2"
  local vault_path="$3"
  local prefix="$4"

  if ! kubectl -n "$namespace" get secret "$secret_name" >/dev/null 2>&1; then
    echo "SKIP missing k8s secret: $namespace/$secret_name -> kv/$vault_path"
    return 0
  fi

  local keys
  keys="$(kubectl -n "$namespace" get secret "$secret_name" -o json | jq -r --arg prefix "$prefix" '.data | keys | map(select(startswith($prefix))) | join(",")')"
  if [ -z "$keys" ] || [ "$keys" = "null" ]; then
    echo "SKIP no ${prefix} keys in k8s secret: $namespace/$secret_name"
    return 0
  fi

  echo "RESTORE $namespace/$secret_name -> kv/$vault_path [$keys]"

  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi

  kubectl -n "$namespace" get secret "$secret_name" -o json \
    | jq --arg prefix "$prefix" '.data | with_entries(select(.key | startswith($prefix))) | map_values(@base64d)' \
    | vault kv put "kv/$vault_path" -
}

restore_secret_excluding_prefix() {
  local namespace="$1"
  local secret_name="$2"
  local vault_path="$3"
  local prefix="$4"

  if ! kubectl -n "$namespace" get secret "$secret_name" >/dev/null 2>&1; then
    echo "SKIP missing k8s secret: $namespace/$secret_name -> kv/$vault_path"
    return 0
  fi

  local keys
  keys="$(kubectl -n "$namespace" get secret "$secret_name" -o json | jq -r --arg prefix "$prefix" '.data | keys | map(select(startswith($prefix) | not)) | join(",")')"
  if [ -z "$keys" ] || [ "$keys" = "null" ]; then
    echo "SKIP no non-${prefix} keys in k8s secret: $namespace/$secret_name"
    return 0
  fi

  echo "RESTORE $namespace/$secret_name -> kv/$vault_path [$keys]"

  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi

  kubectl -n "$namespace" get secret "$secret_name" -o json \
    | jq --arg prefix "$prefix" '.data | with_entries(select(.key | startswith($prefix) | not)) | map_values(@base64d)' \
    | vault kv put "kv/$vault_path" -
}

echo "==> Restoring ExternalSecrets-backed values from Kubernetes Secrets"

restore_secret traefik    cloudflared-secrets                         k8s/core/networking/cloudflare/credentials
restore_secret tools      authentik-secrets                           k8s/core/security/authentik
restore_secret security   crowdsec-secrets                            k8s/core/security/crowdsec/db
restore_secret traefik    crowdsec-bouncer-secrets                    k8s/core/security/crowdsec/traefik

restore_secret tools      freshrss-secrets-db                         k8s/tools/rss/freshrss/db
restore_secret tools      freshrss-secrets-oidc                       k8s/tools/rss/freshrss/oidc

restore_secret monitoring grafana-secrets-admin                       k8s/core/monitoring/grafana/admin
restore_secret monitoring grafana-secrets-github-app                  k8s/core/monitoring/grafana/github-app
restore_secret monitoring grafana-secrets-github-oidc                 k8s/core/monitoring/grafana/github-oidc
restore_secret monitoring grafana-secrets-oidc                        k8s/core/monitoring/grafana/oidc
restore_secret monitoring grafana-secrets-db                          k8s/core/monitoring/grafana/db
restore_secret monitoring alertmanager-secrets-notifications          k8s/core/monitoring/alertmanager/notifications
restore_secret monitoring monitoring-secrets-shared                   k8s/core/monitoring/shared

restore_secret tools      freedium-secrets-app                        k8s/tools/web/freedium/app
restore_secret tools      freedium-secrets-db                         k8s/tools/web/freedium/db
restore_secret tools      homepage-secrets-app                        k8s/tools/dashboards/homepage
restore_secret tools      linkwarden-secrets-db                       k8s/tools/web/linkwarden/db
restore_secret tools      linkwarden-secrets-app                      k8s/tools/web/linkwarden/app
restore_secret tools      karakeep-secrets-app                        k8s/tools/web/karakeep/app

restore_secret tools      vaultwarden-secrets-db                      k8s/core/security/vaultwarden/db
restore_secret_excluding_prefix tools vaultwarden-secrets-app          k8s/core/security/vaultwarden/app SMTP_
restore_secret_matching_prefix  tools vaultwarden-secrets-app          k8s/core/tools/emails/smtp SMTP_
restore_secret infra      terraform-shared-backend-secrets-db         k8s/core/tools/iac/terraform-shared-backend/db

echo "==> Done."
echo "==> Secrets that were not present in Kubernetes must be recreated manually:"
echo "    - kv/k8s/core/cicd/github-actions-runner/github-app"
echo "    - kv/k8s/tools/productivity/appflowy/app"
