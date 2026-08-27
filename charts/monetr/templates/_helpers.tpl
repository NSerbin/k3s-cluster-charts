{{- define "monetr.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "monetr.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "monetr.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "monetr.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "monetr.waitImage" -}}
{{- printf "%s:%s" .Values.waitImage.repository .Values.waitImage.tag -}}
{{- end -}}

{{- define "monetr.postgresName" -}}
{{- printf "%s-postgres" (include "monetr.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "monetr.redisName" -}}
{{- printf "%s-redis" (include "monetr.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "monetr.minioName" -}}
{{- printf "%s-minio" (include "monetr.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "monetr.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "monetr.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "monetr.labels" -}}
app.kubernetes.io/name: {{ include "monetr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "monetr.selectorLabels" -}}
app.kubernetes.io/name: {{ include "monetr.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
