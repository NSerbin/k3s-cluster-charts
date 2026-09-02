{{- define "paperless-ngx.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "paperless-ngx.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "paperless-ngx.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "paperless-ngx.waitImage" -}}
{{- printf "%s:%s" .Values.waitImage.repository .Values.waitImage.tag -}}
{{- end -}}

{{- define "paperless-ngx.postgresName" -}}
{{- printf "%s-postgres" (include "paperless-ngx.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "paperless-ngx.redisName" -}}
{{- printf "%s-redis" (include "paperless-ngx.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "paperless-ngx.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "paperless-ngx.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "paperless-ngx.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "paperless-ngx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "paperless-ngx.selectorLabels" -}}
app.kubernetes.io/name: {{ include "paperless-ngx.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "paperless-ngx.env" -}}
- name: PAPERLESS_REDIS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: PAPERLESS_REDIS
- name: PAPERLESS_DBHOST
  value: {{ include "paperless-ngx.postgresName" . | quote }}
- name: PAPERLESS_DBPORT
  value: {{ .Values.postgres.service.port | quote }}
- name: PAPERLESS_DBNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: POSTGRES_DB
- name: PAPERLESS_DBUSER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: POSTGRES_USER
- name: PAPERLESS_DBPASS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: POSTGRES_PASSWORD
- name: PAPERLESS_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: PAPERLESS_SECRET_KEY
- name: PAPERLESS_ADMIN_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: PAPERLESS_ADMIN_USER
- name: PAPERLESS_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: PAPERLESS_ADMIN_PASSWORD
- name: PAPERLESS_ADMIN_MAIL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: PAPERLESS_ADMIN_MAIL
- name: PAPERLESS_SOCIALACCOUNT_PROVIDERS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: PAPERLESS_SOCIALACCOUNT_PROVIDERS
- name: PAPERLESS_URL
  value: {{ .Values.config.url | quote }}
- name: PAPERLESS_TIME_ZONE
  value: {{ .Values.config.timeZone | quote }}
- name: PAPERLESS_OCR_LANGUAGE
  value: {{ .Values.config.ocrLanguage | quote }}
- name: PAPERLESS_APPS
  value: {{ .Values.config.apps | quote }}
- name: PAPERLESS_LOGOUT_REDIRECT_URL
  value: {{ .Values.config.logoutRedirectUrl | quote }}
- name: PAPERLESS_SOCIAL_AUTO_SIGNUP
  value: {{ .Values.config.socialAutoSignup | quote }}
- name: PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS
  value: {{ .Values.config.socialAccountAllowSignups | quote }}
- name: PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS
  value: {{ .Values.config.socialAccountSyncGroups | quote }}
- name: PAPERLESS_DISABLE_REGULAR_LOGIN
  value: {{ .Values.config.disableRegularLogin | quote }}
- name: PAPERLESS_REDIRECT_LOGIN_TO_SSO
  value: {{ .Values.config.redirectLoginToSso | quote }}
- name: PAPERLESS_ALLOWED_HOSTS
  value: {{ .Values.config.allowedHosts | quote }}
- name: PAPERLESS_CSRF_TRUSTED_ORIGINS
  value: {{ .Values.config.trustedOrigins | quote }}
{{- range $key, $value := .Values.config.extraEnv }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
