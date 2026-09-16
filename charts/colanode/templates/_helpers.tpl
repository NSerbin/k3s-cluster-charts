{{- define "colanode.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "colanode.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "colanode.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "colanode.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "colanode.waitImage" -}}
{{- printf "%s:%s" .Values.waitImage.repository .Values.waitImage.tag -}}
{{- end -}}

{{- define "colanode.postgresName" -}}
{{- printf "%s-postgres" (include "colanode.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "colanode.redisName" -}}
{{- printf "%s-redis" (include "colanode.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "colanode.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "colanode.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "colanode.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "colanode.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "colanode.selectorLabels" -}}
app.kubernetes.io/name: {{ include "colanode.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "colanode.env" -}}
- name: NODE_ENV
  value: "production"
- name: PORT
  value: {{ .Values.service.targetPort | quote }}
- name: CONFIG
  value: {{ .Values.config.configMountPath | quote }}
- name: POSTGRES_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: POSTGRES_URL
- name: REDIS_URL
  valueFrom:
    secretKeyRef:
      name: {{ .Values.secrets.existingSecret | quote }}
      key: REDIS_URL
{{- end -}}
