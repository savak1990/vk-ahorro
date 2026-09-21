{{/*
Keyed on the chart name, not a hard-coded string, so a sibling chart can copy
this file unchanged.
*/}}
{{- define "svc.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "svc.fullname" -}}
{{- if eq .Release.Name (include "svc.name" .) -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name (include "svc.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "svc.labels" -}}
app.kubernetes.io/name: {{ include "svc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "svc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "svc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "svc.host" -}}
{{- required "host is required: the platform passes it in at install time" .Values.host -}}
{{- end -}}

{{- define "svc.image" -}}
{{- $tag := required "image.tag is required: the full commit SHA, never latest" .Values.image.tag -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end -}}

{{/*
A moving tag cached on a node is never re-pulled under IfNotPresent, so the
node keeps serving an old build. A commit SHA can never move.
*/}}
{{- define "svc.pullPolicy" -}}
{{- if .Values.image.pullPolicy -}}
{{- .Values.image.pullPolicy -}}
{{- else if regexMatch "^[0-9a-f]{40}$" .Values.image.tag -}}
IfNotPresent
{{- else -}}
Always
{{- end -}}
{{- end -}}
