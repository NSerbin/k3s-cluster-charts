{{- define "n8n.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "n8n.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "n8n.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "n8n.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "n8n.waitImage" -}}
{{- printf "%s:%s" .Values.waitImage.repository .Values.waitImage.tag -}}
{{- end -}}

{{- define "n8n.postgresName" -}}
{{- printf "%s-postgres" (include "n8n.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "n8n.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "n8n.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "n8n.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "n8n.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "n8n.selectorLabels" -}}
app.kubernetes.io/name: {{ include "n8n.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "n8n.env" -}}
- name: N8N_PORT
  value: {{ .Values.service.targetPort | quote }}
- name: N8N_HOST
  value: {{ .Values.app.host | quote }}
- name: N8N_PROTOCOL
  value: {{ .Values.app.protocol | quote }}
- name: N8N_EDITOR_BASE_URL
  value: {{ printf "%s://%s" .Values.app.protocol .Values.app.host | quote }}
- name: WEBHOOK_URL
  value: {{ printf "%s://%s/" .Values.app.protocol .Values.app.host | quote }}
- name: GENERIC_TIMEZONE
  value: {{ .Values.app.timezone | quote }}
- name: TZ
  value: {{ .Values.app.timezone | quote }}
- name: N8N_DIAGNOSTICS_ENABLED
  value: {{ .Values.app.diagnosticsEnabled | quote }}
- name: N8N_RUNNERS_ENABLED
  value: {{ .Values.app.runnersEnabled | quote }}
- name: N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS
  value: {{ .Values.app.enforceSettingsFilePermissions | quote }}
- name: N8N_SECURE_COOKIE
  value: {{ .Values.app.secureCookie | quote }}
- name: N8N_BLOCK_ENV_ACCESS_IN_NODE
  value: {{ .Values.app.blockEnvAccessInNode | quote }}
- name: N8N_GIT_NODE_DISABLE_BARE_REPOS
  value: {{ .Values.app.gitNodeDisableBareRepos | quote }}
- name: N8N_PROXY_HOPS
  value: "1"
- name: DB_TYPE
  value: postgresdb
- name: DB_POSTGRESDB_HOST
  value: {{ include "n8n.postgresName" . | quote }}
- name: DB_POSTGRESDB_PORT
  value: {{ .Values.postgres.service.port | quote }}
- name: DB_POSTGRESDB_DATABASE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: POSTGRES_DB
- name: DB_POSTGRESDB_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: POSTGRES_USER
- name: DB_POSTGRESDB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: POSTGRES_PASSWORD
- name: N8N_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: N8N_ENCRYPTION_KEY
{{- end -}}

