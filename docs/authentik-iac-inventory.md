# Authentik IaC Inventory

Last checked: 2026-08-23
Authentik version observed in cluster: `2026.8.0`

## Goal

Move Authentik application/provider configuration out of manual UI state and into reproducible IaC, while keeping client secrets in Vault and delivered through External Secrets Operator.

## Recommended Pattern

Use Authentik Blueprints rendered and mounted by the `authentik` Helm chart.

Why:

- Blueprints are native Authentik IaC and are re-applied by Authentik itself.
- File-based blueprints mounted under `/blueprints` are discovered automatically.
- Blueprint entries are transactional: a failing blueprint rolls back instead of partially applying.
- Blueprints support `!Env`, so client secrets can come from Kubernetes env vars populated by ESO-backed Secrets.

Recommended Kubernetes shape:

- Add a `ConfigMap` template in `charts/authentik/templates/blueprints-configmap.yaml`.
- Mount it into both `authentik-server` and `authentik-worker` under a custom path such as `/blueprints/k3s/apps.yaml`.
- Add an ESO-managed Secret such as `authentik-apps-oidc-secrets`.
- Inject the Secret into Authentik worker/server env vars.
- Use blueprint `!Env` for all `client_id` and `client_secret` values.

Vault path strategy:

- Keep app-owned OIDC material under each app path when the app already consumes it directly.
- Create one Authentik ESO Secret that references those same Vault paths and exposes them as env vars to Authentik.
- Do not duplicate values in two Vault paths.

Example env names:

- `ARGOCD_OIDC_CLIENT_ID`
- `ARGOCD_OIDC_CLIENT_SECRET`
- `GRAFANA_OIDC_CLIENT_ID`
- `GRAFANA_OIDC_CLIENT_SECRET`
- `KARAKEEP_OIDC_CLIENT_ID`
- `KARAKEEP_OIDC_CLIENT_SECRET`
- `MCP_GATEWAY_OIDC_CLIENT_ID`
- `MCP_GATEWAY_OIDC_CLIENT_SECRET`
- `VAULT_OIDC_CLIENT_ID`
- `VAULT_OIDC_CLIENT_SECRET`
- `FRESHRSS_OIDC_CLIENT_ID`
- `FRESHRSS_OIDC_CLIENT_SECRET`
- `TREK_OIDC_CLIENT_ID`
- `TREK_OIDC_CLIENT_SECRET`
- `SURE_OIDC_CLIENT_ID`
- `SURE_OIDC_CLIENT_SECRET`

## Redirect URI Rule For Authentik 2026.5+

For OAuth/OIDC providers, Redirect URIs now have explicit types.

- Login callbacks must be `authorization`.
- Logout redirects must be `post_logout`.
- Do not mix logout URLs into `authorization`.
- Do not mark login callbacks as `post_logout`.

Only add `post_logout` URIs for applications that actually send or support `post_logout_redirect_uri`.

## Current Authentik Application Inventory

This was read from the live cluster via `ak shell`. Client secrets were intentionally not printed.

| App | Slug | Provider | Type | Launch URL | Current status |
| --- | --- | --- | --- | --- | --- |
| k3s-argocd | `argocd` | `k3s-argocd-provider` | OAuth2 | `https://argo.nserbin.com` | Active |
| k3s-freshrss | `rss` | `k3s-freshrss-provider` | OAuth2 | `https://rss.nserbin.com` | Active |
| k3s-grafana | `monitor` | `k3s-grafana-provider` | OAuth2 | `https://monitor.nserbin.com` | Active |
| k3s-karakeep | `k3s-karakeep` | `k3s-karakeep-provider` | OAuth2 | `https://bookmarks.nserbin.com` | Active |
| k3s-mcp | `k3s-mcp` | `k3s-mcp-provider` | OAuth2 | `https://mcp.nserbin.com` | Active |
| k3s-vault | `vault` | `k3s-vault-provider` | OAuth2 | `https://secrets.nserbin.com` | Active |
| k3s-kuma | `status` | `k3s-kuma-provider` | OAuth2 + Proxy | `https://status.nserbin.com/` | Legacy/candidate for removal |
| k3s-trek | `trek` | `k3s-trek-provider` | OAuth2/OIDC | `https://travels.nserbin.com` | Added as Helm blueprint |
| k3s-appflowy | `appflowy` | `k3s-appflowy-provider` | SAML | `https://wiki.nserbin.com` | Added as Helm blueprint |
| k3s-homepage | `homepage` | `k3s-homepage-provider` | OAuth2/OIDC | `https://home.nserbin.com` | Added as Helm blueprint |
| k3s-sure | `sure` | `k3s-sure-provider` | OAuth2/OIDC | `https://money.nserbin.com` | Added as Helm blueprint |

## Current Redirect URI Inventory

All observed Redirect URIs are currently typed as `authorization`.

### Argo CD

Provider: `k3s-argocd-provider`

Authorization callbacks:

- `https://argo.nserbin.com/api/dex/callback`
- `https://localhost:8085/auth/callback`

Notes:

- `localhost:8085` is useful for Argo CD CLI SSO flows.
- Do not add post logout unless Argo CD starts sending one.

### FreshRSS

Provider: `k3s-freshrss-provider`

Authorization callbacks:

- `https://rss.nserbin.com/i/oidc/`
- `https://rss.nserbin.com:443/i/oidc/`

Notes:

- Keep both if FreshRSS still alternates between implicit `443` and no explicit port.

### Grafana

Provider: `k3s-grafana-provider`

Authorization callbacks:

- `https://monitor.nserbin.com/login/generic_oauth`

Potential post logout:

- Only add if Grafana sends `post_logout_redirect_uri`.
- Candidate would usually be `https://monitor.nserbin.com/login` or `https://monitor.nserbin.com/`.

### Karakeep

Provider: `k3s-karakeep-provider`

Authorization callbacks:

- `https://bookmarks.nserbin.com/api/auth/callback/custom`

Potential post logout:

- Only add if Karakeep/NextAuth sends `post_logout_redirect_uri`.
- Candidate would usually be `https://bookmarks.nserbin.com/`.

### MCP Gateway / ContextForge

Provider: `k3s-mcp-provider`

Authorization callbacks:

- `https://mcp.nserbin.com/auth/sso/callback/authentik`

Current special mapping:

- `MCP Gateway OAuth Mapping: OpenID email verified`

Notes:

- This custom mapping currently exists manually in Authentik and should be captured in the blueprint before rebuilding providers from IaC.

Potential post logout:

- Only add if ContextForge sends `post_logout_redirect_uri`.
- Candidate would usually be `https://mcp.nserbin.com/login` or `https://mcp.nserbin.com/`.

### Vault

Provider: `k3s-vault-provider`

Authorization callbacks:

- `https://secrets.nserbin.com/ui/vault/auth/oidc/oidc/callback`
- `https://secrets.nserbin.com/oidc/callback`
- `http://localhost:8250/oidc/callback`

Notes:

- `localhost:8250` is required for Vault CLI OIDC login flows.
- Current property mappings only include `profile`; verify whether Vault roles require `email` or groups before changing mappings.

### Uptime Kuma / Status

Provider: `k3s-kuma-provider`

Authorization callbacks:

- `https://status.nserbin.com/outpost.goauthentik.io/callback?X-authentik-auth-callback=true`
- `https://status.nserbin.com/?X-authentik-auth-callback=true`

Proxy provider:

- External host: `https://status.nserbin.com/`
- Internal host: `http://status.nserbin.com:3001`

Notes:

- This app appears to be legacy/stale based on the current cluster direction. Prefer removing from Authentik IaC if Uptime Kuma remains disabled.

## Apps Added As Authentik IaC Blueprints

### TREK

Chart supports OIDC env vars. The Authentik provider/application is now declared through the `authentik` Helm chart blueprint.

- Application slug: `trek`
- Launch URL: `https://travels.nserbin.com`
- Authorization callback: `https://travels.nserbin.com/api/auth/oidc/callback`
- Scope: `openid email profile groups`
- Client ID/secret: from Vault path `k8s/tools/web/trek`

### AppFlowy

Authentik's official AppFlowy integration uses SAML, not OIDC. The Authentik provider/application is now declared through the `authentik` Helm chart blueprint.

- Application slug: `appflowy`
- Launch URL: `https://wiki.nserbin.com`
- SAML ACS URL: `https://wiki.nserbin.com/gotrue/sso/saml/acs`
- SAML audience: `https://wiki.nserbin.com/gotrue/sso/saml/metadata`
- SAML metadata/issuer URL: `https://auth.nserbin.com/application/saml/appflowy/metadata/`
- Certificate/private key: from Vault path `k8s/tools/productivity/appflowy/app`

### Homepage

Homepage supports built-in OIDC authentication in version `2.x`; the chart pins `v2.1.2` for this integration.

- Application slug: `homepage`
- Launch URL: `https://home.nserbin.com`
- Authorization callback: `https://home.nserbin.com/api/auth/callback/homepage-oidc`
- Scope: `openid email profile`
- Client ID/secret: from Vault path `k8s/tools/dashboards/homepage`

### Sure

Sure supports self-hosted OIDC through environment variables and keeps the app-side settings in Vault via ESO.

- Application slug: `sure`
- Launch URL: `https://money.nserbin.com`
- Authorization callback: `https://money.nserbin.com/auth/openid_connect/callback`
- Client ID/secret: from Vault path `k8s/tools/finance/sure/oidc`

## Migration Plan

1. Export the current Authentik applications/providers to a draft blueprint to capture exact model fields for Authentik `2026.8.0`.
2. Add Authentik chart support for:
   - blueprint ConfigMaps
   - mounting blueprint files into server/worker
   - injecting app OIDC env vars from an ESO-managed Secret
3. Create `charts/authentik/templates/blueprints-apps-configmap.yaml`.
4. Create/update `charts/external-secrets-operator/values.yaml` entries for an `authentik-apps-oidc-secrets` Secret in `tools`.
5. Move one app first, preferably `k3s-mcp` or `k3s-karakeep`, because they are simple OAuth2 providers and actively used.
6. Sync Authentik and verify:
   - Blueprint instance is discovered.
   - Provider exists with expected `authorization` redirect URIs.
   - Client ID/secret match the app's Kubernetes Secret.
   - Login still works.
7. Migrate the rest one by one.
8. Remove stale `k3s-kuma` provider/application if Uptime Kuma remains retired.

## Open Decisions

- Whether client IDs should be manually fixed in Vault, or generated once and then stored in Vault.
- Whether group/role policy bindings should be part of the same blueprint or a separate `authentik-access-policies` blueprint.
- Whether post logout URIs should be enabled per app after validating actual logout behavior.
- Whether stale Authentik apps should be declared `absent` in IaC or deleted manually once confirmed unused.
