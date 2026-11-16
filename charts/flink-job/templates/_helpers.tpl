{{- define "flink-job.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "flink-job.fullname" -}}
{{- .Release.Name | trunc 45 | trimSuffix "-" -}}
{{- end -}}

{{- define "flink-job.labels" -}}
app.kubernetes.io/name: {{ include "flink-job.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}

{{- define "flink-job.serviceAccountName" -}}
{{- default "flink" .Values.serviceAccount.name -}}
{{- end -}}

{{/* s3://bucket/prefix/release — every path the job writes hangs off this */}}
{{- define "flink-job.s3Base" -}}
s3://{{ required "checkpoints.bucket is required" .Values.checkpoints.bucket }}/{{ .Values.checkpoints.prefix }}/{{ include "flink-job.fullname" . }}
{{- end -}}
