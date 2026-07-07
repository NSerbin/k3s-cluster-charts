# AGENTS.md

Guia de trabajo para este repo de charts del cluster k3s.

## Contexto

Este repo contiene los Helm charts y las aplicaciones de Argo CD que despliegan servicios self-hosted sobre el cluster k3s.

La regla general es:

- `argocd/apps/<app>.yaml` declara la app de Argo.
- `charts/<app>/` contiene el chart propio o wrapper del servicio.
- `charts/<app>/values.yaml` es la fuente principal de configuracion runtime.
- Cloudflare publica los hostnames mediante `cloudflared`.
- Traefik enruta internamente usando CRDs, principalmente `IngressRoute` y `Middleware`.
- Los secretos se inyectan con External Secrets Operator desde Vault.

## Estructura Esperada

Para una app nueva, crear:

- `argocd/apps/<app>.yaml`
- `charts/<app>/Chart.yaml`
- `charts/<app>/values.yaml`
- `charts/<app>/templates/_helpers.tpl`
- `charts/<app>/templates/deployment.yaml` o `statefulset.yaml`
- `charts/<app>/templates/service.yaml`
- `charts/<app>/templates/ingressroute.yaml` si expone HTTP
- `charts/<app>/templates/externalsecret.yaml` solo si realmente necesita secretos
- PVCs solo si la app necesita persistencia real

No crear secretos, PVCs, DBs ni middlewares "por las dudas".

## Argo CD

Cada app debe tener una `Application` en `argocd/apps`.

Patron base:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app>
  namespace: argocd
spec:
  revisionHistoryLimit: 5
  project: default
  source:
    repoURL: "https://github.com/NSerbin/k3s-cluster-charts.git"
    targetRevision: "main"
    path: "charts/<app>"
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: "https://kubernetes.default.svc"
    namespace: <namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Usar `tools`, `monitoring`, `infra`, `security`, `traefik`, `argocd` segun corresponda. No inventar namespaces si ya existe uno logico.

## Helm Charts

Preferencias:

- Usar `fullnameOverride` cuando el nombre default quede feo o duplicado.
- Mantener nombres legibles: `authentik-server`, `freedium-postgres`, `bentopdf`, etc.
- Separar componentes con `app.kubernetes.io/component`.
- Usar helpers locales para `name`, `fullname`, `labels`, `selectorLabels`.
- Mantener `values.yaml` como API del chart.
- Evitar templates demasiado magicos.

Los charts deben renderizar con:

```bash
helm lint charts/<app>
helm template <app> charts/<app> --namespace <namespace>
```

## Versiones

No usar `latest`.

Las imagenes deben tener tag explicito. Si tiene sentido por seguridad/reproducibilidad, pinnear digest.

Cada `Chart.yaml` debe incluir `home:` apuntando al release upstream del proyecto, por ejemplo:

```yaml
home: https://github.com/<org>/<repo>/releases
```

## Traefik

No usamos Ingress clasico salvo que haya una razon fuerte. El patron normal es Traefik CRD:

- `IngressRoute` para rutas HTTP.
- `Middleware` para headers, auth, redirects, etc.

El entrypoint habitual para apps detras de Cloudflare Tunnel es:

```yaml
entryPoints:
  - web
```

No poner TLS en el chart si TLS termina en Cloudflare.

Cloudflared suele enviar a:

```text
http://traefik.traefik.svc.cluster.local:80
```

con `httpHostHeader` igual al hostname publico.

## Cloudflare

Este repo solo define el routing interno de Kubernetes. DNS, Access Applications y service tokens viven en los repos Terraform de Cloudflare.

Cuando se agrega una app publica:

1. Agregar route en `charts/cloudflared/values.yaml`.
2. Agregar `IngressRoute` en el chart de la app.
3. Agregar DNS/Access en Terraform Cloudflare.
4. Validar DNS y HTTP headers despues de aplicar.

## Secrets, Vault y ESO

Solo crear `ExternalSecret` si la app necesita secretos.

Convencion general:

- Secret de Kubernetes con nombre explicito: `<app>-secrets-<scope>`.
- Vault path por dominio funcional:
  - `k8s/tools/web/<app>/app`
  - `k8s/tools/web/<app>/oidc`
  - `k8s/core/monitoring/<app>/<scope>`
  - `k8s/core/security/<app>/<scope>`
  - `k8s/core/cicd/<app>/<scope>`

ESO debe leer desde `ClusterSecretStore` llamado `vault`.

No hardcodear secretos en `values.yaml`.

Si una app no necesita secretos, dejarla sin ESO. Ejemplo: BentoPDF simple no necesita Vault/ESO.

## Persistencia

Usar PVC solo cuando hay datos reales que preservar.

Antes de cambiar nombres de `StatefulSet`, `volumeClaimTemplates` o labels de selectores:

- Revisar impacto sobre PVCs existentes.
- Preparar backup si los datos importan.
- No cambiar selectors de Deployments/StatefulSets existentes sin plan de recreacion.

Para DBs, preferir `StatefulSet` con service estable y PVC nuevo cuando se esta corrigiendo naming para no pisar datos.

## Auth

Hay tres patrones:

- App con OIDC propio: configurar OIDC en la app y secretos con ESO.
- App sin auth propia: proteger delante con Cloudflare Access y, si hace falta, Authentik `forwardAuth` en Traefik.
- MCP/servicios tecnicos: Cloudflare Access con service token cuando sea consumo machine-to-machine.

No asumir que una app soporta OIDC. Si no tiene login propio, Authentik va como proxy delante, no dentro de la app.

## Recursos

El cluster es chico y el disco importa.

Definir requests/limits razonables en cada componente. Evitar defaults pesados. Evitar CI/CD runners pesados en este cluster salvo que haya capacidad dedicada.

Usar servicios auxiliares solo cuando son necesarios. Si una app puede desactivar MinIO, Redis, workers o AI, dejar switches claros en `values.yaml`.

## Validacion Antes De Cerrar

Para cambios de chart:

```bash
helm lint charts/<app>
helm template <app> charts/<app> --namespace <namespace>
```

Para cambios aplicados:

```bash
kubectl -n <namespace> get pods,svc,ingressroute,middleware
kubectl -n <namespace> logs deploy/<app> --tail=100
```

Para rutas publicas:

```bash
curl -skI https://<host>/
```

Para apps detras de Cloudflare Access, validar tambien directo contra Traefik:

```bash
kubectl -n traefik port-forward svc/traefik 8080:80
curl -I -H 'Host: <host>' http://127.0.0.1:8080/
```

## Estilo De Cambios

- Mantener cambios chicos y enfocados.
- No refactorizar charts no relacionados.
- No borrar PVCs ni recursos con datos sin confirmacion explicita.
- No revertir cambios ajenos.
- Preferir configuracion declarativa sobre comandos manuales.
- Si algo queda pendiente de aplicar en Terraform o Argo, decirlo explicitamente.
