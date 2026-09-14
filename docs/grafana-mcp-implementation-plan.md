# Grafana MCP implementation plan

## Objective

Add the official Grafana MCP server to the personal k3s workflow so Codex/VS Code can use Grafana as an observability source during troubleshooting.

Primary use case:

- Ask Codex questions about dashboards, Prometheus datasource queries, alert state, resource trends, and incident windows without leaving VS Code.
- Keep Kubernetes access for live state, logs, events, rollouts, and changes.
- Keep Grafana MCP read-first and least-privilege.

Decision:

- Use the official Grafana image: `grafana/mcp-grafana`.
- Deploy Grafana MCP inside the k3s cluster.
- Run it with streamable HTTP transport.
- Keep the Kubernetes Service internal first (`ClusterIP`).
- The Grafana service account token must come from Vault through External Secrets Operator.
- Configure VS Code, Codex, and other MCP clients to reach the in-cluster MCP endpoint through a local port-forward first.
- Do not expose Grafana MCP through Traefik or Cloudflare at the beginning.
- Do not use the Prometheus MCP server for now; Grafana MCP can query Prometheus through Grafana datasources.

## Current cluster context

Relevant current services:

- Grafana: `https://monitor.nserbin.com`
- Internal Grafana service: `http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local`
- Prometheus: `https://prometheus.nserbin.com`
- Internal Prometheus service: `http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`
- Namespace: `monitoring`
- Secrets pattern: Vault -> External Secrets Operator -> Kubernetes Secret
- GitOps pattern: Argo CD `Application` under `argocd/apps`
- Ingress pattern: Traefik `IngressRoute` plus Cloudflare Tunnel

Important current detail:

- Prometheus retention is `24h`, so Grafana MCP is best for recent troubleshooting, dashboard discovery, and query assistance, not long-term forensic analysis.

## Recommended architecture

### Phase 1: in-cluster Grafana MCP deployment

Run the MCP server as a Kubernetes Deployment in `monitoring`.

Flow:

1. Grafana service account token is created in Grafana.
2. Token is stored in Vault at `kv/k8s/core/monitoring/grafana/mcp`.
3. External Secrets Operator syncs the token into a Kubernetes Secret in `monitoring`.
4. Argo CD deploys a `grafana-mcp` Helm chart.
5. The Deployment starts `grafana/mcp-grafana` using streamable HTTP on port `8000`.
6. The MCP pod talks to Grafana through the internal service URL.
7. VS Code/Codex connects to the MCP server through `kubectl port-forward`.

Why this first deployment shape:

- Token stays in Vault/External Secrets, not on the workstation.
- No public endpoint.
- Fits the existing Argo CD app pattern.
- Uses internal cluster DNS for Grafana.
- Easy to expose later if there is a real need.

### Phase 2: optional protected remote access

Only do this after the internal deployment proves useful.

Flow:

1. Add an auth layer in front of the MCP endpoint.
2. Add a Traefik `IngressRoute` only if the auth story is explicit.
3. Add Cloudflare Tunnel routing only after validating access controls.
4. Configure clients to use the protected URL.

Important:

- Do not publish this through Cloudflare Tunnel by default.
- Do not add `mcp.nserbin.com` unless there is a strong reason and an auth layer in front.
- Do not depend on Grafana auth alone; the MCP server itself is the thing being exposed.

## Grafana permissions

Create a dedicated Grafana service account. Do not use a personal token.

Recommended initial role:

- Viewer, plus only the minimum RBAC permissions needed for datasource query and dashboard read.

Desired capabilities:

- Search dashboards.
- Read dashboard summaries.
- Read panel queries.
- List datasources.
- Query the Prometheus datasource.
- Read alert rules and alert state.
- Generate links/deeplinks.

Avoid initially:

- Dashboard create/update.
- Alert rule write.
- Annotation create/update.
- Snapshot create/delete.
- Incident creation.
- Admin tools.
- OnCall tools.
- User/team/role listing unless explicitly needed.

Operational policy:

- Read-only by default.
- Any mutation in Grafana requires explicit human confirmation.
- Any Kubernetes mutation requires explicit human confirmation.

## Vault secret

Suggested Vault KV path:

```text
kv/k8s/core/monitoring/grafana/mcp
```

Suggested key:

```text
GRAFANA_SERVICE_ACCOUNT_TOKEN
```

Example command:

```bash
vault kv put kv/k8s/core/monitoring/grafana/mcp \
  GRAFANA_SERVICE_ACCOUNT_TOKEN="<grafana-service-account-token>"
```

Assumptions:

- Vault is already integrated with External Secrets Operator.
- The `external-secrets-operator` chart owns the current `ClusterSecretStore` and `ExternalSecret` pattern.
- The `monitoring` namespace already exists through the kube-prometheus-stack Argo app.

## Kubernetes implementation

### Step 1: create the Grafana service account

In Grafana:

1. Create a dedicated service account named `grafana-mcp`.
2. Start with Viewer-level access plus any minimum RBAC needed for datasource query.
3. Generate a token.
4. Do not reuse personal admin credentials.

Store the token in Vault:

```bash
vault kv put kv/k8s/core/monitoring/grafana/mcp \
  GRAFANA_SERVICE_ACCOUNT_TOKEN="<grafana-service-account-token>"
```

### Step 2: add an ExternalSecret

Add a new `ExternalSecret` entry in:

```text
charts/external-secrets-operator/values.yaml
```

Suggested entry:

```yaml
- name: grafana-mcp-secrets
  namespace: monitoring
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  target:
    name: grafana-mcp-secrets
    creationPolicy: Owner
    deletionPolicy: Retain
  dataFrom:
    - extract:
        key: k8s/core/monitoring/grafana/mcp
        conversionStrategy: Default
        decodingStrategy: None
        metadataPolicy: None
```

Expected Kubernetes Secret:

```text
monitoring/grafana-mcp-secrets
```

Expected key:

```text
GRAFANA_SERVICE_ACCOUNT_TOKEN
```

### Step 3: create the Helm chart

Create:

```text
charts/grafana-mcp/
  Chart.yaml
  values.yaml
  templates/deployment.yaml
  templates/service.yaml
```

Suggested `Chart.yaml`:

```yaml
apiVersion: v2
name: grafana-mcp
description: Official Grafana MCP server for the k3s observability stack
type: application
version: 0.1.0
appVersion: "0.17.0"
```

Suggested `values.yaml`:

```yaml
replicaCount: 1

image:
  repository: grafana/mcp-grafana
  # Pin the tested version instead of using latest.
  # As of 2026-06-23, Docker Hub shows 0.17.0 as the recent official tag.
  tag: "0.17.0"
  pullPolicy: IfNotPresent

grafana:
  url: "http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local"
  secretName: grafana-mcp-secrets
  tokenKey: GRAFANA_SERVICE_ACCOUNT_TOKEN

mcp:
  port: 8000
  transport: streamable-http
  endpointPath: /mcp
  disabledFlags:
    - --disable-oncall

service:
  type: ClusterIP
  port: 8000

resources:
  requests:
    cpu: 25m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi

securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

Suggested Deployment behavior:

```yaml
args:
  - -t
  - streamable-http
  - --address
  - :8000
  - --endpoint-path
  - /mcp
  - --disable-oncall
env:
  - name: GRAFANA_URL
    value: http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local
  - name: GRAFANA_SERVICE_ACCOUNT_TOKEN
    valueFrom:
      secretKeyRef:
        name: grafana-mcp-secrets
        key: GRAFANA_SERVICE_ACCOUNT_TOKEN
```

Suggested `templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana-mcp
  labels:
    app.kubernetes.io/name: grafana-mcp
    app.kubernetes.io/component: mcp
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: grafana-mcp
  template:
    metadata:
      labels:
        app.kubernetes.io/name: grafana-mcp
        app.kubernetes.io/component: mcp
    spec:
      containers:
        - name: grafana-mcp
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          args:
            - -t
            - {{ .Values.mcp.transport | quote }}
            - --address
            - ":{{ .Values.mcp.port }}"
            - --endpoint-path
            - {{ .Values.mcp.endpointPath | quote }}
            {{- range .Values.mcp.disabledFlags }}
            - {{ . | quote }}
            {{- end }}
          env:
            - name: GRAFANA_URL
              value: {{ .Values.grafana.url | quote }}
            - name: GRAFANA_SERVICE_ACCOUNT_TOKEN
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.grafana.secretName | quote }}
                  key: {{ .Values.grafana.tokenKey | quote }}
          ports:
            - name: http
              containerPort: {{ .Values.mcp.port }}
              protocol: TCP
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
```

Suggested `templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana-mcp
  labels:
    app.kubernetes.io/name: grafana-mcp
    app.kubernetes.io/component: mcp
spec:
  type: {{ .Values.service.type }}
  selector:
    app.kubernetes.io/name: grafana-mcp
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
```

### Step 4: create the Argo CD app

Create:

```text
argocd/apps/grafana-mcp.yaml
```

Suggested app:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: grafana-mcp
  namespace: argocd
spec:
  revisionHistoryLimit: 5
  project: default

  source:
    repoURL: "https://github.com/NSerbin/k3s-cluster-charts.git"
    targetRevision: "main"
    path: "charts/grafana-mcp"
    helm:
      valueFiles:
        - values.yaml

  destination:
    server: "https://kubernetes.default.svc"
    namespace: monitoring

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

### Step 5: verify in-cluster deployment

Check Argo CD:

```bash
kubectl -n argocd get application grafana-mcp
```

Check secret:

```bash
kubectl -n monitoring get secret grafana-mcp-secrets
```

Check pods:

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=grafana-mcp
```

Check service:

```bash
kubectl -n monitoring get svc grafana-mcp
```

Port-forward locally:

```bash
kubectl -n monitoring port-forward svc/grafana-mcp 8000:8000
```

Expected MCP URL from the workstation:

```text
http://localhost:8000/mcp
```

Do not add Traefik or Cloudflare until this works locally.

## Client configuration

### Codex in VS Code

Recommended user-level config:

```toml
[mcp_servers.grafana]
url = "http://localhost:8000/mcp"
startup_timeout_sec = 10
tool_timeout_sec = 90
default_tools_approval_mode = "prompt"
enabled = true
```

Steps:

1. Start the port-forward:

```bash
kubectl -n monitoring port-forward svc/grafana-mcp 8000:8000
```

2. Open Codex MCP settings or edit:

```text
~/.codex/config.toml
```

3. Add the `mcp_servers.grafana` block above.
4. Restart the Codex session or use `/mcp` to inspect active MCP servers.
5. Ask a read-only test question:

```text
Using Grafana MCP, list the available Grafana datasources and identify the Prometheus datasource.
```

Notes:

- The MCP server is in the cluster.
- Codex only connects to `localhost:8000`, which is backed by `kubectl port-forward`.
- The Grafana token never exists in Codex config.

### Native VS Code / GitHub Copilot MCP

VS Code stores MCP server configuration in `mcp.json`. Use user-level config first.

Steps:

1. Start the port-forward:

```bash
kubectl -n monitoring port-forward svc/grafana-mcp 8000:8000
```

2. In VS Code, open Command Palette.
3. Run:

```text
MCP: Open User Configuration
```

4. Add:

```json
{
  "servers": {
    "grafana": {
      "type": "http",
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

5. Run:

```text
MCP: List Servers
```

6. Start or restart `grafana`.
7. Confirm trust when VS Code asks.
8. Open Copilot Chat in Agent mode.
9. Use the tool picker to confirm Grafana MCP tools are visible.
10. Ask:

```text
Using the Grafana MCP tools, list available datasources and tell me which one is Prometheus.
```

Workspace-level alternative:

```text
.vscode/mcp.json
```

Use workspace-level only if this repo should advertise the cluster MCP config to every VS Code user opening it.

### Optional: stable local endpoint helper

Because both Codex and VS Code expect `localhost:8000`, keep a small helper script later:

```text
scripts/port-forward-grafana-mcp.sh
```

Draft:

```bash
#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring port-forward svc/grafana-mcp 8000:8000
```

This script does not contain secrets.

## Codex operating rule

Use this instruction when asking Codex to troubleshoot incidents:

```text
For observability troubleshooting, use Grafana MCP first for dashboards, metrics, datasource queries, alert state, and time-window analysis.
Use kubectl for current cluster state, logs, events, rollouts, and Kubernetes changes.
Do not modify Grafana or Kubernetes resources without explicit confirmation.
Prefer read-only investigation unless I ask for a fix.
```

Recommended split:

- Grafana MCP answers "what changed over time?"
- `kubectl` answers "what is happening right now?"
- Git/Argo answers "what changed in desired state?"

## Example incident prompts

```text
Use Grafana MCP to check whether Traefik 5xx increased in the last 2 hours.
Then inspect the relevant Kubernetes resources with kubectl if needed.
Do not change anything.
```

```text
Look at this Helm chart and use Grafana MCP to compare actual CPU and memory usage for the deployment over the last 24h.
Suggest better requests and limits, but do not edit files yet.
```

```text
Use Grafana MCP to find the dashboard/panel that shows restarts or OOMKills for this namespace.
Give me a deeplink and summarize what it shows.
```

```text
Use Grafana MCP to check whether this Argo rollout correlated with latency, 5xx, or pod restarts.
Use kubectl only to confirm current pod state.
```

## Verification checklist

Cluster checks:

1. Confirm the Vault path exists:

```bash
vault kv get kv/k8s/core/monitoring/grafana/mcp
```

2. Confirm External Secrets created the Kubernetes Secret:

```bash
kubectl -n monitoring get secret grafana-mcp-secrets
```

3. Confirm Argo CD sees the app:

```bash
kubectl -n argocd get application grafana-mcp
```

4. Confirm the MCP pod is running:

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=grafana-mcp
```

5. Confirm the internal service exists:

```bash
kubectl -n monitoring get svc grafana-mcp
```

6. Start the local tunnel:

```bash
kubectl -n monitoring port-forward svc/grafana-mcp 8000:8000
```

Client checks:

1. In Codex, inspect active MCP servers:

```text
/mcp
```

2. In VS Code, run:

```text
MCP: List Servers
```

3. Ask a read-only Grafana question:

```text
Using Grafana MCP, list the available Grafana datasources and identify the Prometheus datasource.
```

4. Ask a metric question:

```text
Using Grafana MCP, query Prometheus through Grafana for node CPU usage over the last hour.
```

Failure modes:

- If the Kubernetes Secret is missing, check External Secrets sync and Vault path.
- If the pod is `CreateContainerConfigError`, check the secret name/key.
- If the pod cannot reach Grafana, check the internal `GRAFANA_URL` and service DNS.
- If the client cannot connect, confirm the port-forward is running.
- If Grafana returns unauthorized, review the service account role/scopes.
- If tools are visible but fail on write operations, confirm that the service account is intentionally read-only.

## Argo CD MCP implementation plan

Argo CD MCP is the natural second MCP for this cluster because Argo CD owns the desired state for the apps under `argocd/apps`.

Primary use case:

- Ask which apps are degraded, out of sync, or recently changed.
- Inspect app resource trees from the IDE.
- Compare GitOps app state with Grafana metrics during incidents.
- Fetch managed resource context, events, and workload logs through Argo CD.

Decision:

- Use `argoproj-labs/mcp-for-argocd`.
- Deploy it inside the k3s cluster.
- Run it with HTTP transport.
- Enable `MCP_READ_ONLY=true` at first.
- Keep the Kubernetes Service internal first (`ClusterIP`).
- Store the Argo CD API token in Vault and sync it with External Secrets.
- Access it from clients through `kubectl port-forward` on local port `8001`.
- Do not expose it through Traefik or Cloudflare at the beginning.

### Argo CD MCP security posture

Start read-only.

The Argo CD MCP server supports `MCP_READ_ONLY=true`, which disables mutation tools:

- `create_application`
- `update_application`
- `delete_application`
- `sync_application`
- `run_resource_action`

That is the right initial mode for this cluster.

Use it for:

- app listing
- app details
- sync/health status
- resource tree
- managed resources
- workload logs
- resource events

Do not enable write/sync operations until there is a clear operational reason and an explicit approval model.

### Argo CD API token

Suggested Vault KV path:

```text
kv/k8s/core/cicd/argocd/mcp
```

Suggested key:

```text
ARGOCD_API_TOKEN
```

Suggested Argo CD base URL inside the cluster:

```text
http://argocd-server.argocd.svc.cluster.local
```

Token creation options:

1. Preferred: create a dedicated Argo CD account or project role for MCP with read-only permissions.
2. Generate an API token for that account/role.
3. Store only the token in Vault.

Example Vault write:

```bash
vault kv put kv/k8s/core/cicd/argocd/mcp \
  ARGOCD_API_TOKEN="<argocd-api-token>"
```

Avoid:

- using your personal Argo CD token
- using the admin token
- storing the token in `values.yaml`, Codex config, or VS Code config

### Step 1: add an ExternalSecret

Add a new `ExternalSecret` entry in:

```text
charts/external-secrets-operator/values.yaml
```

Suggested entry:

```yaml
- name: argocd-mcp-secrets
  namespace: argocd
  secretStoreRef:
    name: vault
    kind: ClusterSecretStore
  target:
    name: argocd-mcp-secrets
    creationPolicy: Owner
    deletionPolicy: Retain
  dataFrom:
    - extract:
        key: k8s/core/cicd/argocd/mcp
        conversionStrategy: Default
        decodingStrategy: None
        metadataPolicy: None
```

Expected Kubernetes Secret:

```text
argocd/argocd-mcp-secrets
```

Expected key:

```text
ARGOCD_API_TOKEN
```

### Step 2: create the Helm chart

Create:

```text
charts/argocd-mcp/
  Chart.yaml
  values.yaml
  templates/deployment.yaml
  templates/service.yaml
```

Suggested `Chart.yaml`:

```yaml
apiVersion: v2
name: argocd-mcp
description: Argo CD MCP server for the k3s GitOps control plane
type: application
version: 0.1.0
appVersion: "0.0.0"
```

Suggested `values.yaml`:

```yaml
replicaCount: 1

image:
  repository: ghcr.io/argoproj-labs/mcp-for-argocd
  tag: "v0.8.0"
  pullPolicy: IfNotPresent

argocd:
  baseUrl: "http://argocd-server.argocd.svc.cluster.local"
  secretName: argocd-mcp-secrets
  tokenKey: ARGOCD_API_TOKEN

mcp:
  port: 3000
  path: /mcp
  readOnly: true
  stateless: true

service:
  type: ClusterIP
  port: 3000

resources:
  requests:
    cpu: 25m
    memory: 64Mi
  limits:
    cpu: 300m
    memory: 256Mi

securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

Notes:

- Use the official GHCR image and pin a release tag. `v0.8.0` is the latest upstream release as of 2026-06-24.
- `MCP_READ_ONLY=true` is the important guardrail.
- `--stateless` is recommended for Kubernetes HTTP deployments because it avoids session stickiness requirements.
- Keep `replicaCount: 1` until the deployment is verified.

Suggested `templates/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-mcp
  labels:
    app.kubernetes.io/name: argocd-mcp
    app.kubernetes.io/component: mcp
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-mcp
  template:
    metadata:
      labels:
        app.kubernetes.io/name: argocd-mcp
        app.kubernetes.io/component: mcp
    spec:
      containers:
        - name: argocd-mcp
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          args:
            - http
            {{- if .Values.mcp.stateless }}
            - --stateless
            {{- end }}
          env:
            - name: PORT
              value: {{ .Values.mcp.port | quote }}
            - name: ARGOCD_BASE_URL
              value: {{ .Values.argocd.baseUrl | quote }}
            - name: ARGOCD_API_TOKEN
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.argocd.secretName | quote }}
                  key: {{ .Values.argocd.tokenKey | quote }}
            - name: MCP_READ_ONLY
              value: {{ .Values.mcp.readOnly | quote }}
          ports:
            - name: http
              containerPort: {{ .Values.mcp.port }}
              protocol: TCP
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
```

Suggested `templates/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: argocd-mcp
  labels:
    app.kubernetes.io/name: argocd-mcp
    app.kubernetes.io/component: mcp
spec:
  type: {{ .Values.service.type }}
  selector:
    app.kubernetes.io/name: argocd-mcp
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
```

### Step 3: create the Argo CD app

Create:

```text
argocd/apps/argocd-mcp.yaml
```

Suggested app:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-mcp
  namespace: argocd
spec:
  revisionHistoryLimit: 5
  project: default

  source:
    repoURL: "https://github.com/NSerbin/k3s-cluster-charts.git"
    targetRevision: "main"
    path: "charts/argocd-mcp"
    helm:
      valueFiles:
        - values.yaml

  destination:
    server: "https://kubernetes.default.svc"
    namespace: argocd

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
```

### Step 4: verify in-cluster deployment

Check Argo CD:

```bash
kubectl -n argocd get application argocd-mcp
```

Check secret:

```bash
kubectl -n argocd get secret argocd-mcp-secrets
```

Check pods:

```bash
kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-mcp
```

Check service:

```bash
kubectl -n argocd get svc argocd-mcp
```

Port-forward locally:

```bash
kubectl -n argocd port-forward svc/argocd-mcp 8001:3000
```

Expected MCP URL from the workstation:

```text
http://localhost:8001/mcp
```

Optional low-level health check:

```bash
curl -i http://localhost:8001/healthz
```

Do not add Traefik or Cloudflare until this works locally.

### Codex client configuration

Add to:

```text
~/.codex/config.toml
```

Recommended config:

```toml
[mcp_servers.argocd]
url = "http://localhost:8001/mcp"
startup_timeout_sec = 10
tool_timeout_sec = 90
default_tools_approval_mode = "prompt"
enabled = true
```

Steps:

1. Start the port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-mcp 8001:3000
```

2. Restart the Codex session or inspect MCP servers:

```text
/mcp
```

3. Ask a read-only test:

```text
Using Argo CD MCP, list all Argo CD applications and summarize which ones are unhealthy or out of sync.
```

### Native VS Code / GitHub Copilot MCP configuration

Open:

```text
MCP: Open User Configuration
```

Add:

```json
{
  "servers": {
    "argocd": {
      "type": "http",
      "url": "http://localhost:8001/mcp"
    }
  }
}
```

Steps:

1. Start the port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-mcp 8001:3000
```

2. Run:

```text
MCP: List Servers
```

3. Start or restart `argocd`.
4. Confirm trust when VS Code asks.
5. Open Copilot Chat in Agent mode.
6. Ask:

```text
Using the Argo CD MCP tools, list applications and identify degraded or out-of-sync apps.
```

### Argo CD MCP operating rule

Use this instruction when troubleshooting:

```text
Use Argo CD MCP for desired state, sync status, health status, application resource trees, managed resources, and GitOps context.
Use Grafana MCP for metrics and alert timelines.
Use kubectl for live Kubernetes state, logs, events, and any direct cluster changes.
Do not sync, delete, create, update, or run resource actions in Argo CD without explicit confirmation.
```

### Argo CD MCP verification checklist

Cluster checks:

1. Confirm the Vault path exists:

```bash
vault kv get kv/k8s/core/cicd/argocd/mcp
```

2. Confirm External Secrets created the Kubernetes Secret:

```bash
kubectl -n argocd get secret argocd-mcp-secrets
```

3. Confirm the MCP pod is running:

```bash
kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-mcp
```

4. Confirm the service exists:

```bash
kubectl -n argocd get svc argocd-mcp
```

Client checks:

1. Start the port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-mcp 8001:3000
```

2. Ask:

```text
Using Argo CD MCP, list all applications.
```

3. Ask:

```text
Using Argo CD MCP, get the resource tree for kube-prometheus-stack.
```

Failure modes:

- If the pod is `CreateContainerConfigError`, check `argocd-mcp-secrets` and the `ARGOCD_API_TOKEN` key.
- If the MCP server cannot reach Argo CD, check `ARGOCD_BASE_URL`.
- If Argo CD returns unauthorized, review the token account/role.
- If mutation tools are unexpectedly available, confirm `MCP_READ_ONLY=true`.
- If VS Code/Codex cannot connect, confirm `kubectl port-forward` is still running.

## Other MCP candidates for this cluster

### High-value candidates

#### GitHub MCP

Why it fits:

- This cluster is GitOps-driven.
- Argo CD deploys from GitHub repos.
- Useful for issues, PRs, commits, review comments, and release context.

Best use:

- "What PR changed this chart?"
- "Summarize the diff that introduced this incident."
- "Open a draft PR with the Helm fix."

Risk:

- Can mutate repos if granted write permissions.

Recommendation:

- Useful now.
- Keep write operations behind explicit confirmation.

#### Argo CD MCP

Status:

- Planned above as the second cluster-deployed MCP after Grafana MCP.

Why it fits:

- Your cluster is based on Argo CD apps.
- Incident response often starts with sync state, health state, and app diffs.

Best use:

- "Which apps are degraded?"
- "What changed in desired state?"
- "Is this app OutOfSync?"
- "Compare live vs desired for this app."

Risk:

- Argo operations can trigger syncs, rollbacks, or app changes depending on permissions.

Recommendation:

- Very useful, but add after Grafana MCP.
- Start read-only.
- Prefer the Argo project/labs implementation over random community forks when possible.

#### Kubernetes MCP

Why it fits:

- Gives structured Kubernetes tools to agents.
- Could reduce ad-hoc shell parsing.

Best use:

- "List unhealthy pods."
- "Describe this deployment."
- "Fetch relevant pod logs."

Risk:

- Duplicates what Codex can already do with `kubectl`.
- Can become dangerous if it has broad write permissions.
- For this setup, direct `kubectl` is already available and transparent.

Recommendation:

- Not urgent.
- Consider later if you want tool-level guardrails instead of raw shell access.
- If added, make it read-only first.

### Medium-value candidates

#### Cloudflare MCP

Why it fits:

- You use Cloudflare Tunnel for public access.
- Helpful for DNS, tunnels, routes, and access policies.

Best use:

- "Check the tunnel route for monitor.nserbin.com."
- "Verify DNS and Cloudflare config for this service."

Risk:

- Cloudflare changes can expose internal services.

Recommendation:

- Useful, but only with tight permissions.
- Good candidate after Grafana and Argo CD.

#### Vault Access

Recommendation:

- Do not run a general-purpose MCP server for Vault in the cluster.
- Use direct Vault CLI access through an explicit, temporary port-forward when needed.
- Prefer narrow purpose-built commands/scripts over a general MCP surface for secret inspection.

Rationale:

- Vault is the cluster's highest-impact secret boundary.
- A general MCP server could expose secret read/write capabilities to any compromised MCP client/session.
- Public DNS or always-on remote access for Vault automation is not acceptable for this environment.

#### Terraform MCP

Why it fits:

- Proxmox/k3s infrastructure is Terraform-managed.

Best use:

- Explaining module/resource relationships.
- Planning VM/node changes.

Risk:

- Terraform apply/destroy operations are high impact.

Recommendation:

- Lower priority.
- Codex can already read Terraform files locally.
- Add only if it gives a clear advantage over local repo analysis.

### Low-priority or not needed now

#### Prometheus MCP

Status:

- Explicitly discarded for now.

Reason:

- Grafana MCP can query Prometheus through the Grafana datasource.
- Avoids another token, another MCP server, and another operational surface.

#### Browser/Playwright MCP

Why it might fit:

- Useful for testing Grafana, Argo, Homepage, Authentik, and app UIs.

Risk:

- More useful for UI testing than cluster incident response.

Recommendation:

- Add later if you want automated UI checks or screenshots.

#### Sentry MCP

Status:

- Only useful if Sentry is part of the stack later.

Recommendation:

- Skip for now.

## Suggested implementation order

Grafana MCP:

1. Create Grafana service account.
2. Store the token in Vault at `kv/k8s/core/monitoring/grafana/mcp`.
3. Add the `grafana-mcp-secrets` ExternalSecret to `charts/external-secrets-operator/values.yaml`.
4. Create the `charts/grafana-mcp` Helm chart.
5. Create the `argocd/apps/grafana-mcp.yaml` Argo CD app.
6. Let Argo CD sync and verify the pod/service.
7. Start `kubectl port-forward svc/grafana-mcp 8000:8000 -n monitoring`.
8. Configure Codex in `~/.codex/config.toml`.
9. Configure native VS Code MCP in user `mcp.json`.
10. Test read-only queries from Codex and VS Code.
11. Add an operating rule to `AGENTS.md` or a reusable prompt.
12. Tune Grafana RBAC and disabled tool categories.

Argo CD MCP:

13. Create a read-only Argo CD account/project role for MCP.
14. Store the token in Vault at `kv/k8s/core/cicd/argocd/mcp`.
15. Add the `argocd-mcp-secrets` ExternalSecret to `charts/external-secrets-operator/values.yaml`.
16. Create the `charts/argocd-mcp` Helm chart.
17. Create the `argocd/apps/argocd-mcp.yaml` Argo CD app.
18. Let Argo CD sync and verify the pod/service.
19. Start `kubectl port-forward svc/argocd-mcp 8001:3000 -n argocd`.
20. Configure Codex in `~/.codex/config.toml`.
21. Configure native VS Code MCP in user `mcp.json`.
22. Test read-only Argo CD app queries from Codex and VS Code.
23. Add the Argo CD MCP operating rule to `AGENTS.md` or a reusable prompt.

After both:

24. Consider GitHub MCP.
25. Consider protected remote access for Grafana MCP and Argo CD MCP only after an explicit auth layer exists.

## Sources checked

- Grafana MCP documentation: `grafana/mcp-grafana`, Docker setup, streamable HTTP transport, Grafana service account token requirement.
- Grafana MCP repository: feature list, RBAC guidance, disabled/default tool categories.
- Argo CD MCP repository: HTTP transport, Argo CD API token handling, `MCP_READ_ONLY`, stateless mode, and available tools.
- Codex manual: MCP configuration in `~/.codex/config.toml`, shared CLI/IDE config, streamable HTTP support, tool approval settings.
- VS Code MCP docs: user/workspace `mcp.json`, HTTP server config, MCP commands, trust prompt, and server management.
- Local cluster manifests: kube-prometheus-stack values, Argo CD app layout, External Secrets pattern, Traefik and Cloudflare Tunnel values.
- Candidate MCP projects/docs: GitHub MCP, Argo CD MCP, Kubernetes MCP, Cloudflare MCP.
