{{- define "outline.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "outline.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "outline.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "outline.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "outline.waitImage" -}}
{{- printf "%s:%s" .Values.waitImage.repository .Values.waitImage.tag -}}
{{- end -}}

{{- define "outline.postgresName" -}}
{{- printf "%s-postgres" (include "outline.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "outline.redisName" -}}
{{- printf "%s-redis" (include "outline.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "outline.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "outline.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "outline.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "outline.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "outline.selectorLabels" -}}
app.kubernetes.io/name: {{ include "outline.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "outline.env" -}}
- name: URL
  value: {{ .Values.config.url | quote }}
- name: PORT
  value: {{ .Values.config.port | quote }}
- name: WEB_CONCURRENCY
  value: {{ .Values.config.webConcurrency | quote }}
- name: FORCE_HTTPS
  value: {{ .Values.config.forceHttps | quote }}
- name: LOG_LEVEL
  value: {{ .Values.config.logLevel | quote }}
- name: PGSSLMODE
  value: disable
- name: SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SECRET_KEY
- name: UTILS_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: UTILS_SECRET
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: DATABASE_URL
- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: REDIS_URL
- name: FILE_STORAGE
  value: {{ .Values.config.fileStorage | quote }}
- name: FILE_STORAGE_LOCAL_ROOT_DIR
  value: {{ .Values.config.fileStorageLocalRootDir | quote }}
- name: FILE_STORAGE_UPLOAD_MAX_SIZE
  value: {{ .Values.config.fileStorageUploadMaxSize | quote }}
- name: OIDC_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_CLIENT_ID
- name: OIDC_CLIENT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_CLIENT_SECRET
- name: OIDC_AUTH_URI
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_AUTH_URI
- name: OIDC_TOKEN_URI
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_TOKEN_URI
- name: OIDC_USERINFO_URI
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_USERINFO_URI
- name: OIDC_LOGOUT_URI
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_LOGOUT_URI
- name: OIDC_USERNAME_CLAIM
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_USERNAME_CLAIM
- name: OIDC_DISPLAY_NAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_DISPLAY_NAME
- name: OIDC_SCOPES
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_SCOPES
{{- range $key, $value := .Values.config.extraEnv }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
