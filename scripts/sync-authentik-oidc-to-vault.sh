#!/usr/bin/env bash
set -euo pipefail

AUTHENTIK_NAMESPACE="${AUTHENTIK_NAMESPACE:-tools}"
AUTHENTIK_DEPLOYMENT="${AUTHENTIK_DEPLOYMENT:-deploy/authentik-server}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need kubectl
need jq
need openssl
need vault

vault kv get -format=json kv/k8s/core/security/authentik >/dev/null

json="$(kubectl -n "$AUTHENTIK_NAMESPACE" exec "$AUTHENTIK_DEPLOYMENT" -- ak shell -c '
import json
from authentik.providers.oauth2.models import OAuth2Provider

names = [
    "k3s-argocd-provider",
    "k3s-freshrss-provider",
    "k3s-grafana-provider",
    "k3s-karakeep-provider",
    "k3s-mcp-provider",
    "k3s-paperless-provider",
    "k3s-vault-provider",
]

out = {}
for name in names:
    provider = OAuth2Provider.objects.filter(name=name).first()
    if provider:
        out[name] = {
            "client_id": provider.client_id,
            "client_secret": provider.client_secret,
        }

print(json.dumps(out, separators=(",", ":")))
' | awk '/^\{/{line=$0} END{print line}')"

provider_value() {
  local provider="$1"
  local field="$2"
  jq -er --arg provider "$provider" --arg field "$field" '.[$provider][$field]' <<<"$json"
}

optional_existing_or_generated() {
  local path="$1"
  local key="$2"
  local generator="$3"

  local current
  current="$(vault kv get -format=json "$path" 2>/dev/null | jq -r --arg key "$key" '.data.data[$key] // empty' || true)"
  if [ -n "$current" ]; then
    printf '%s' "$current"
    return
  fi

  case "$generator" in
    client_id)
      printf '%s-%s' "$4" "$(openssl rand -hex 12)"
      ;;
    secret)
      openssl rand -base64 48 | tr -d '\n'
      ;;
    auth_secret)
      openssl rand -base64 48 | tr -d '\n'
      ;;
    *)
      echo "Unknown generator: $generator" >&2
      exit 1
      ;;
  esac
}

patch() {
  local path="$1"
  shift
  if vault kv get -format=json "$path" >/dev/null 2>&1; then
    vault kv patch "$path" "$@" >/dev/null
  else
    vault kv put "$path" "$@" >/dev/null
  fi
  echo "patched $path"
}

base="https://auth.nserbin.com"

patch kv/k8s/core/cicd/argocd/oidc \
  OIDC_CLIENT_ID="$(provider_value k3s-argocd-provider client_id)" \
  OIDC_CLIENT_SECRET="$(provider_value k3s-argocd-provider client_secret)" \
  OIDC_ISSUER="$base/application/o/argocd/" \
  OIDC_DISCOVERY_URL="$base/application/o/argocd/.well-known/openid-configuration"

patch kv/k8s/tools/rss/freshrss/oidc \
  OIDC_CLIENT_ID="$(provider_value k3s-freshrss-provider client_id)" \
  OIDC_CLIENT_SECRET="$(provider_value k3s-freshrss-provider client_secret)" \
  OIDC_PROVIDER_METADATA_URL="$base/application/o/rss/.well-known/openid-configuration" \
  OIDC_SCOPES="openid email profile" \
  OIDC_REMOTE_USER_CLAIM="preferred_username"

patch kv/k8s/core/monitoring/grafana/oidc \
  AUTHENTIK_CLIENT_ID="$(provider_value k3s-grafana-provider client_id)" \
  AUTHENTIK_CLIENT_SECRET="$(provider_value k3s-grafana-provider client_secret)" \
  AUTHENTIK_AUTH_URL="$base/application/o/authorize/" \
  AUTHENTIK_TOKEN_URL="$base/application/o/token/" \
  AUTHENTIK_API_URL="$base/application/o/userinfo/" \
  AUTHENTIK_SIGNOUT_REDIRECT_URL="$base/application/o/grafana/end-session/"

patch kv/k8s/tools/web/karakeep/oidc \
  NEXTAUTH_URL="https://bookmarks.nserbin.com" \
  OAUTH_CLIENT_ID="$(provider_value k3s-karakeep-provider client_id)" \
  OAUTH_CLIENT_SECRET="$(provider_value k3s-karakeep-provider client_secret)" \
  OAUTH_WELLKNOWN_URL="$base/application/o/k3s-karakeep/.well-known/openid-configuration" \
  OAUTH_PROVIDER_NAME="Authentik" \
  OAUTH_ALLOW_DANGEROUS_EMAIL_ACCOUNT_LINKING="true"

patch kv/k8s/core/security/mcp-gateway/app \
  SSO_GENERIC_ENABLED="true" \
  SSO_GENERIC_PROVIDER_ID="authentik" \
  SSO_GENERIC_DISPLAY_NAME="Authentik" \
  SSO_GENERIC_CLIENT_ID="$(provider_value k3s-mcp-provider client_id)" \
  SSO_GENERIC_CLIENT_SECRET="$(provider_value k3s-mcp-provider client_secret)" \
  SSO_GENERIC_AUTHORIZATION_URL="$base/application/o/authorize/" \
  SSO_GENERIC_TOKEN_URL="$base/application/o/token/" \
  SSO_GENERIC_USERINFO_URL="$base/application/o/userinfo/" \
  SSO_GENERIC_ISSUER="$base/application/o/k3s-mcp/" \
  SSO_GENERIC_JWKS_URI="$base/application/o/k3s-mcp/jwks/" \
  SSO_GENERIC_SCOPE="openid email profile"

patch kv/k8s/core/security/vault/oidc \
  OIDC_CLIENT_ID="$(provider_value k3s-vault-provider client_id)" \
  OIDC_CLIENT_SECRET="$(provider_value k3s-vault-provider client_secret)" \
  OIDC_DISCOVERY_URL="$base/application/o/vault/.well-known/openid-configuration" \
  OIDC_ISSUER="$base/application/o/vault/"

trek_id="$(optional_existing_or_generated kv/k8s/tools/web/trek OIDC_CLIENT_ID client_id trek)"
trek_secret="$(optional_existing_or_generated kv/k8s/tools/web/trek OIDC_CLIENT_SECRET secret)"
patch kv/k8s/tools/web/trek \
  OIDC_CLIENT_ID="$trek_id" \
  OIDC_CLIENT_SECRET="$trek_secret" \
  OIDC_ISSUER="$base/application/o/trek/" \
  OIDC_DISCOVERY_URL="$base/application/o/trek/.well-known/openid-configuration" \
  OIDC_DISPLAY_NAME="Authentik" \
  OIDC_SCOPE="openid email profile groups"

homepage_id="$(optional_existing_or_generated kv/k8s/tools/dashboards/homepage HOMEPAGE_OIDC_CLIENT_ID client_id homepage)"
homepage_secret="$(optional_existing_or_generated kv/k8s/tools/dashboards/homepage HOMEPAGE_OIDC_CLIENT_SECRET secret)"
homepage_auth_secret="$(optional_existing_or_generated kv/k8s/tools/dashboards/homepage HOMEPAGE_AUTH_SECRET auth_secret)"
patch kv/k8s/tools/dashboards/homepage \
  HOMEPAGE_AUTH_SECRET="$homepage_auth_secret" \
  HOMEPAGE_OIDC_CLIENT_ID="$homepage_id" \
  HOMEPAGE_OIDC_CLIENT_SECRET="$homepage_secret" \
  HOMEPAGE_AUTH_ENABLED="true" \
  HOMEPAGE_EXTERNAL_URL="https://home.nserbin.com" \
  HOMEPAGE_OIDC_ISSUER="$base/application/o/homepage/" \
  HOMEPAGE_OIDC_NAME="Authentik" \
  HOMEPAGE_OIDC_SCOPE="openid email profile"

libredb_id="$(optional_existing_or_generated kv/k8s/tools/database/libredb/oidc OIDC_CLIENT_ID client_id libredb)"
libredb_secret="$(optional_existing_or_generated kv/k8s/tools/database/libredb/oidc OIDC_CLIENT_SECRET secret)"
patch kv/k8s/tools/database/libredb/oidc \
  OIDC_CLIENT_ID="$libredb_id" \
  OIDC_CLIENT_SECRET="$libredb_secret" \
  OIDC_ISSUER="$base/application/o/libredb/" \
  OIDC_DISCOVERY_URL="$base/application/o/libredb/.well-known/openid-configuration" \
  OIDC_SCOPE="openid profile email groups" \
  OIDC_ROLE_CLAIM="libredb_roles" \
  OIDC_ADMIN_ROLES="admin,libredb-admin"

sure_id="$(optional_existing_or_generated kv/k8s/tools/finance/sure/oidc OIDC_CLIENT_ID client_id sure)"
sure_secret="$(optional_existing_or_generated kv/k8s/tools/finance/sure/oidc OIDC_CLIENT_SECRET secret)"
patch kv/k8s/tools/finance/sure/oidc \
  OIDC_CLIENT_ID="$sure_id" \
  OIDC_CLIENT_SECRET="$sure_secret" \
  OIDC_ISSUER="$base/application/o/sure/" \
  OIDC_REDIRECT_URI="https://money.nserbin.com/auth/openid_connect/callback"

paperless_id="$(optional_existing_or_generated kv/k8s/tools/documents/paperless/oidc OIDC_CLIENT_ID client_id paperless)"
paperless_secret="$(optional_existing_or_generated kv/k8s/tools/documents/paperless/oidc OIDC_CLIENT_SECRET secret)"
patch kv/k8s/tools/documents/paperless/oidc \
  OIDC_CLIENT_ID="$paperless_id" \
  OIDC_CLIENT_SECRET="$paperless_secret" \
  OIDC_DISCOVERY_URL="$base/application/o/paperless/.well-known/openid-configuration"
patch kv/k8s/tools/documents/paperless/app \
  PAPERLESS_SOCIALACCOUNT_PROVIDERS="$(jq -cn \
    --arg client_id "$paperless_id" \
    --arg secret "$paperless_secret" \
    --arg server_url "$base/application/o/paperless/.well-known/openid-configuration" \
    '{
    openid_connect: {
      OAUTH_PKCE_ENABLED: true,
      APPS: [{
        provider_id: "authentik",
        name: "authentik",
        client_id: $client_id,
        secret: $secret,
        settings: {
          server_url: $server_url,
          fetch_userinfo: true
        }
      }],
      SCOPE: ["openid", "profile", "email"]
      }
    }')"

if ! vault kv get -format=json kv/k8s/tools/productivity/appflowy/app 2>/dev/null | jq -e '.data.data.AUTH_SAML_CERT_PEM and .data.data.AUTH_SAML_PRIVATE_KEY_PEM and .data.data.AUTH_SAML_CERT and .data.data.GOTRUE_SAML_PRIVATE_KEY' >/dev/null; then
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  openssl genrsa -traditional -out "$tmpdir/appflowy-saml.key" 2048 >/dev/null 2>&1
  openssl req -x509 -new \
    -key "$tmpdir/appflowy-saml.key" \
    -out "$tmpdir/appflowy-saml.crt" \
    -days 3650 \
    -subj "/CN=k3s-appflowy-saml" >/dev/null 2>&1
  patch kv/k8s/tools/productivity/appflowy/app \
    AUTH_SAML_CERT_PEM="$(cat "$tmpdir/appflowy-saml.crt")" \
    AUTH_SAML_PRIVATE_KEY_PEM="$(cat "$tmpdir/appflowy-saml.key")" \
    AUTH_SAML_CERT="$(awk 'NF && $0 !~ /-----/ {printf "%s", $0}' "$tmpdir/appflowy-saml.crt")" \
    GOTRUE_SAML_PRIVATE_KEY="$(awk 'NF && $0 !~ /-----/ {printf "%s", $0}' "$tmpdir/appflowy-saml.key")" \
    AUTH_SAML_ENABLED="true" \
    GOTRUE_SAML_ENABLED="true" \
    AUTH_SAML_ENTRY_POINT="$base/application/saml/appflowy/" \
    AUTH_SAML_ISSUER="$base/application/saml/appflowy/metadata/" \
    AUTH_SAML_CALLBACK_URL="https://wiki.nserbin.com/gotrue/sso/saml/acs" \
    AUTH_SAML_DEFAULT_REDIRECT_URL="https://wiki.nserbin.com/auth/callback"
else
  patch kv/k8s/tools/productivity/appflowy/app \
    AUTH_SAML_ENABLED="true" \
    GOTRUE_SAML_ENABLED="true" \
    AUTH_SAML_ENTRY_POINT="$base/application/saml/appflowy/" \
    AUTH_SAML_ISSUER="$base/application/saml/appflowy/metadata/" \
    AUTH_SAML_CALLBACK_URL="https://wiki.nserbin.com/gotrue/sso/saml/acs" \
    AUTH_SAML_DEFAULT_REDIRECT_URL="https://wiki.nserbin.com/auth/callback"
fi

echo "done"
