{{- define "sure.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sure.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "sure.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "sure.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "sure.waitImage" -}}
{{- printf "%s:%s" .Values.waitImage.repository .Values.waitImage.tag -}}
{{- end -}}

{{- define "sure.postgresName" -}}
{{- printf "%s-postgres" (include "sure.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sure.redisName" -}}
{{- printf "%s-redis" (include "sure.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "sure.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "sure.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "sure.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "sure.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "sure.selectorLabels" -}}
app.kubernetes.io/name: {{ include "sure.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "sure.env" -}}
- name: RAILS_ENV
  value: {{ .Values.rails.env | quote }}
- name: RAILS_LOG_TO_STDOUT
  value: {{ .Values.rails.logToStdout | quote }}
- name: RAILS_SERVE_STATIC_FILES
  value: {{ .Values.rails.serveStaticFiles | quote }}
- name: SELF_HOSTED
  value: {{ .Values.rails.selfHosted | quote }}
- name: ONBOARDING_STATE
  value: {{ .Values.rails.onboardingState | quote }}
- name: FORCE_SSL
  value: {{ .Values.rails.forceSsl | quote }}
- name: RAILS_FORCE_SSL
  value: {{ .Values.rails.forceSsl | quote }}
- name: RAILS_ASSUME_SSL
  value: {{ .Values.rails.assumeSsl | quote }}
- name: REQUIRE_EMAIL_CONFIRMATION
  value: {{ .Values.rails.requireEmailConfirmation | quote }}
- name: ACTIVE_STORAGE_SERVICE
  value: {{ .Values.rails.activeStorageService | quote }}
- name: APP_HOST
  value: {{ .Values.rails.appHost | quote }}
- name: APP_DOMAIN
  value: {{ .Values.rails.appDomain | quote }}
- name: APP_PROTOCOL
  value: {{ .Values.rails.appProtocol | quote }}
- name: APP_URL
  value: {{ .Values.rails.appUrl | quote }}
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
- name: SECRET_KEY_BASE
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SECRET_KEY_BASE
- name: ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
- name: ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
- name: ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
- name: EMAIL_SENDER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_FROM
- name: SMTP_ADDRESS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_HOST
- name: SMTP_PORT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_PORT
- name: SMTP_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_USERNAME
- name: SMTP_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_PASSWORD
- name: SMTP_TLS_ENABLED
  value: {{ .Values.email.tlsEnabled | quote }}
- name: SMTP_TLS_SKIP_VERIFY
  value: {{ .Values.email.tlsSkipVerify | quote }}
{{- if .Values.oidc.enabled }}
- name: AUTH_PROVIDERS_SOURCE
  value: {{ .Values.oidc.providersSource | quote }}
- name: AUTH_LOCAL_LOGIN_ENABLED
  value: {{ .Values.oidc.localLoginEnabled | quote }}
- name: AUTH_LOCAL_ADMIN_OVERRIDE_ENABLED
  value: {{ .Values.oidc.localAdminOverrideEnabled | quote }}
- name: AUTH_PASSKEY_LOGIN_ENABLED
  value: {{ .Values.oidc.passkeyLoginEnabled | quote }}
- name: AUTH_JIT_MODE
  value: {{ .Values.oidc.jitMode | quote }}
{{- if .Values.oidc.allowedDomains }}
- name: ALLOWED_OIDC_DOMAINS
  value: {{ .Values.oidc.allowedDomains | quote }}
{{- end }}
- name: OIDC_ISSUER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_ISSUER
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
- name: OIDC_REDIRECT_URI
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: OIDC_REDIRECT_URI
- name: OIDC_BUTTON_LABEL
  value: {{ .Values.oidc.buttonLabel | quote }}
- name: OIDC_BUTTON_ICON
  value: {{ .Values.oidc.buttonIcon | quote }}
{{- end }}
{{- range $key, $value := .Values.rails.extraEnv }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
