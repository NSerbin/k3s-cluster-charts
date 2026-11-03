{{- define "shlink.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shlink.fullname" -}}
{{- default (include "shlink.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shlink.postgresName" -}}
{{- printf "%s-postgres" (include "shlink.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "shlink.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "shlink.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "shlink.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shlink.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
