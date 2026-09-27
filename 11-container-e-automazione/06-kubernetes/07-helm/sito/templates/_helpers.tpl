{{/*
Blocchi riusabili, richiamati nei template con include. I file che iniziano con _ non producono manifest.
*/}}

{{/* Le label consigliate da Kubernetes, uguali su tutte le risorse della release */}}
{{- define "sito.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/* Il sottoinsieme che identifica i Pod: non deve cambiare fra una versione e l'altra del chart */}}
{{- define "sito.selector" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
