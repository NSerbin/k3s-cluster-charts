{{- define "cal-diy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cal-diy.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "cal-diy.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "cal-diy.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "cal-diy.waitImage" -}}
{{- printf "%s:%s" .Values.waitImage.repository .Values.waitImage.tag -}}
{{- end -}}

{{- define "cal-diy.postgresName" -}}
{{- printf "%s-postgres" (include "cal-diy.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cal-diy.redisName" -}}
{{- printf "%s-redis" (include "cal-diy.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cal-diy.studioName" -}}
{{- printf "%s-studio" (include "cal-diy.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cal-diy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "cal-diy.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "cal-diy.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "cal-diy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "cal-diy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cal-diy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "cal-diy.env" -}}
- name: NODE_ENV
  value: {{ .Values.app.nodeEnv | quote }}
- name: NEXT_PUBLIC_WEBAPP_URL
  value: {{ .Values.app.webappUrl | quote }}
- name: NEXT_PUBLIC_WEBSITE_URL
  value: {{ .Values.app.websiteUrl | quote }}
- name: NEXT_PUBLIC_EMBED_LIB_URL
  value: {{ .Values.app.embedLibUrl | quote }}
- name: NEXTAUTH_URL
  value: {{ .Values.app.webappUrl | quote }}
- name: WEB_APP_URL
  value: {{ .Values.app.webappUrl | quote }}
- name: NEXT_PUBLIC_API_V2_URL
  value: {{ .Values.app.apiV2Url | quote }}
- name: ALLOWED_HOSTNAMES
  value: {{ .Values.app.allowedHostnames | quote }}
- name: RESERVED_SUBDOMAINS
  value: {{ .Values.app.reservedSubdomains | quote }}
- name: CALCOM_TELEMETRY_DISABLED
  value: {{ .Values.app.telemetryDisabled | quote }}
- name: CRON_ENABLE_APP_SYNC
  value: {{ .Values.app.cronEnableAppSync | quote }}
- name: NEXT_PUBLIC_LOGGER_LEVEL
  value: {{ .Values.app.loggerLevel | quote }}
- name: NEXT_PUBLIC_LICENSE_CONSENT
  value: {{ .Values.app.licenseConsent | quote }}
- name: NEXT_PUBLIC_APP_NAME
  value: {{ .Values.app.appName | quote }}
- name: NEXT_PUBLIC_COMPANY_NAME
  value: {{ .Values.app.companyName | quote }}
- name: NEXT_PUBLIC_SUPPORT_MAIL_ADDRESS
  value: {{ .Values.app.supportEmail | quote }}
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: DATABASE_URL
- name: DATABASE_DIRECT_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: DATABASE_DIRECT_URL
- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: REDIS_URL
- name: NEXTAUTH_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: NEXTAUTH_SECRET
- name: CALENDSO_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: CALENDSO_ENCRYPTION_KEY
- name: CRON_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: CRON_API_KEY
- name: JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: JWT_SECRET
{{- if .Values.email.enabled }}
- name: EMAIL_FROM
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_FROM
- name: EMAIL_FROM_NAME
  value: {{ .Values.email.fromName | quote }}
- name: EMAIL_SERVER_HOST
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_HOST
- name: EMAIL_SERVER_PORT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_PORT
- name: EMAIL_SERVER_USER
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_USERNAME
- name: EMAIL_SERVER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: SMTP_PASSWORD
{{- end }}
{{- range $key, $value := .Values.app.extraEnv }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
