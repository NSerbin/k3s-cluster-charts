{{- define "libredb-wrapper.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "libredb-wrapper.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "libredb-wrapper.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "libredb-wrapper.labels" -}}
app.kubernetes.io/name: {{ include "libredb-wrapper.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "libredb-wrapper.selectorLabels" -}}
app.kubernetes.io/name: {{ include "libredb-wrapper.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "libredb-wrapper.postgresName" -}}
{{- printf "%s-postgres" (include "libredb-wrapper.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
