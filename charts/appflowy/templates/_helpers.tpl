{{- define "appflowy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "appflowy.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "appflowy.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "appflowy.labels" -}}
app.kubernetes.io/name: {{ include "appflowy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "appflowy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "appflowy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "appflowy.postgresName" -}}{{ include "appflowy.fullname" . }}-postgres{{- end -}}
{{- define "appflowy.redisName" -}}{{ include "appflowy.fullname" . }}-redis{{- end -}}
{{- define "appflowy.minioName" -}}{{ include "appflowy.fullname" . }}-minio{{- end -}}
{{- define "appflowy.gotrueName" -}}{{ include "appflowy.fullname" . }}-gotrue{{- end -}}
{{- define "appflowy.cloudName" -}}{{ include "appflowy.fullname" . }}-cloud{{- end -}}
{{- define "appflowy.workerName" -}}{{ include "appflowy.fullname" . }}-worker{{- end -}}
{{- define "appflowy.searchName" -}}{{ include "appflowy.fullname" . }}-search{{- end -}}
{{- define "appflowy.webName" -}}{{ include "appflowy.fullname" . }}-web{{- end -}}
{{- define "appflowy.adminFrontendName" -}}{{ include "appflowy.fullname" . }}-admin-frontend{{- end -}}
{{- define "appflowy.aiName" -}}{{ include "appflowy.fullname" . }}-ai{{- end -}}
