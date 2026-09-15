{{- define "affine.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "affine.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "affine.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "affine.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "affine.waitImage" -}}
{{- printf "%s:%s" .Values.waitImage.repository .Values.waitImage.tag -}}
{{- end -}}

{{- define "affine.postgresName" -}}
{{- printf "%s-postgres" (include "affine.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "affine.redisName" -}}
{{- printf "%s-redis" (include "affine.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "affine.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "affine.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "affine.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "affine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "affine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "affine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "affine.env" -}}
- name: DEPLOYMENT_TYPE
  value: {{ .Values.config.deploymentType | quote }}
- name: AFFINE_SERVER_EXTERNAL_URL
  value: {{ .Values.config.externalUrl | quote }}
- name: AFFINE_SERVER_HOST
  value: {{ .Values.config.host | quote }}
- name: AFFINE_SERVER_HTTPS
  value: {{ .Values.config.https | quote }}
- name: AFFINE_SERVER_PORT
  value: {{ .Values.config.port | quote }}
- name: REDIS_SERVER_HOST
  value: {{ include "affine.redisName" . | quote }}
- name: REDIS_SERVER_PORT
  value: {{ .Values.redis.service.port | quote }}
- name: REDIS_SERVER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: REDIS_PASSWORD
- name: DATABASE_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: DATABASE_URL
- name: AFFINE_PRIVATE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: AFFINE_PRIVATE_KEY
{{- range $key, $value := .Values.config.extraEnv }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
{{- end -}}
