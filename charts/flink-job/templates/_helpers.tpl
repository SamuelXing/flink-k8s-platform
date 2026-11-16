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

{{/*
Extra WITH-clause options for a Kafka table. Empty unless kafka.iamAuth is on.
Used from the .sql files, right after the bootstrap servers line.
*/}}
{{- define "flink-job.kafkaSecurity" -}}
{{- if .Values.kafka.iamAuth }}
  'properties.security.protocol'                   = 'SASL_SSL',
  'properties.sasl.mechanism'                      = 'AWS_MSK_IAM',
  'properties.sasl.jaas.config'                    = 'software.amazon.msk.auth.iam.IAMLoginModule required;',
  'properties.sasl.client.callback.handler.class'  = 'software.amazon.msk.auth.iam.IAMClientCallbackHandler',
{{- end }}
{{- end -}}
