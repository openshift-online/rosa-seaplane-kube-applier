{{/*
Expand the name of the chart.
*/}}
{{- define "kube-applier.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kube-applier.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart label.
*/}}
{{- define "kube-applier.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "kube-applier.labels" -}}
helm.sh/chart: {{ include "kube-applier.chart" . }}
{{ include "kube-applier.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "kube-applier.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kube-applier.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "kube-applier.serviceAccountName" -}}
{{ .Values.kubeApplier.serviceAccount.name }}
{{- end }}

{{- define "kube-applier.listenPort" -}}
{{- $address := . -}}
{{- $suffix := regexFind ":[0-9]+$" $address -}}
{{- if not $suffix -}}
{{- fail (printf "listen address %q must end with :<port>" $address) -}}
{{- end -}}
{{- $host := trimSuffix $suffix $address -}}
{{- if and $host (not (or (regexMatch "^[A-Za-z0-9.-]+$" $host) (regexMatch "^\\[[0-9A-Fa-f:.]+(%[A-Za-z0-9_.-]+)?\\]$" $host))) -}}
{{- fail (printf "listen address %q must use a hostname, IPv4 address, or bracketed IPv6 address" $address) -}}
{{- end -}}
{{- $portString := trimPrefix ":" $suffix -}}
{{- if gt (len $portString) 5 -}}
{{- fail (printf "listen address %q port must be between 1 and 65535" $address) -}}
{{- end -}}
{{- $port := atoi $portString -}}
{{- if or (lt $port 1) (gt $port 65535) -}}
{{- fail (printf "listen address %q port must be between 1 and 65535" $address) -}}
{{- end -}}
{{- $port -}}
{{- end -}}
