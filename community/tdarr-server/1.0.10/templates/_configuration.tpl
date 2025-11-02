{{- define "tdarr.configuration" -}}

  {{- $fullname := include "ix.v1.common.lib.chart.names.fullname" $ -}}

  {{- $webPort := .Values.tdarrNetwork.webPort -}}
  {{- $serverPort := .Values.tdarrNetwork.serverPort -}}

configmap:
  tdarr-server-config:
    enabled: true
    data:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
      serverIP: {{ .Values.tdarrConfig.serverIP | quote }}
      serverPort: {{ $serverPort | quote }}
      webUIPort: {{ $webPort | quote }}
      inContainer: "true"
      ffmpegVersion: {{ .Values.tdarrConfig.ffmpegVersion | quote }}
      internalNode: {{ .Values.tdarrConfig.internalNode | quote }}
      {{- if .Values.tdarrConfig.internalNode }}
      nodeName: {{ .Values.tdarrConfig.nodeName | quote }}
      {{- end }}
      {{- range $env := .Values.tdarrConfig.additionalEnvs }}
      {{ $env.name }}: {{ $env.value | quote }}
      {{- end }}
{{- end -}}
