{{- define "terraform-shared-backend.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "terraform-shared-backend.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "terraform-shared-backend.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "terraform-shared-backend.labels" -}}
app.kubernetes.io/name: {{ include "terraform-shared-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "terraform-shared-backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "terraform-shared-backend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
