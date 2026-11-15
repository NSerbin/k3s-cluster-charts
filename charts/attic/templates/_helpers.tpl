{{- define "attic.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "attic.fullname" -}}
{{- default (include "attic.name" .) .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "attic.labels" -}}
app.kubernetes.io/name: {{ include "attic.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "attic.selectorLabels" -}}
app.kubernetes.io/name: {{ include "attic.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
