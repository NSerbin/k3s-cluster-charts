{{- define "affine.fullname" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "affine.labels" -}}
app.kubernetes.io/name: {{ include "affine.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}

{{- define "affine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "affine.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "affine.postgresName" -}}
{{- printf "%s-postgres" (include "affine.fullname" .) -}}
{{- end -}}

{{- define "affine.redisName" -}}
{{- printf "%s-redis" (include "affine.fullname" .) -}}
{{- end -}}

{{- define "affine.env" -}}
- name: DEPLOYMENT_TYPE
  value: {{ .Values.config.deploymentType | quote }}
- name: AFFINE_SERVER_EXTERNAL_URL
  value: {{ .Values.config.externalUrl | quote }}
- name: AFFINE_SERVER_HOST
  value: {{ .Values.config.host | quote }}
- name: AFFINE_SERVER_HTTPS
  value: "true"
- name: AFFINE_SERVER_PORT
  value: {{ .Values.config.port | quote }}
- name: REDIS_SERVER_HOST
  value: {{ include "affine.redisName" . | quote }}
- name: REDIS_SERVER_PORT
  value: "6379"
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
{{- end -}}
