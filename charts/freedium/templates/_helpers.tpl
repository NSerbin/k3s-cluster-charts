{{- define "freedium.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "freedium.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "freedium.name" . | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "freedium.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end }}

{{- define "freedium.labels" -}}
helm.sh/chart: {{ include "freedium.chart" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "freedium.selectorLabels" -}}
app.kubernetes.io/name: {{ include "freedium.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "freedium.componentLabels" -}}
{{- $component := .component | default "app" -}}
app.kubernetes.io/name: {{ $component }}
app.kubernetes.io/instance: {{ $.Release.Name }}
{{- end }}
