{{- define "tdarr-server.service" -}}
service:
  tdarr-server:
    enabled: true
    primary: true
    type: NodePort
    targetSelector: tdarr-server
    ports:
      webui:
        enabled: true
        primary: true
        port: {{ .Values.tdarrNetwork.webPort }}
        nodePort: {{ .Values.tdarrNetwork.webPort }}
        targetSelector: tdarr-server
      server:
        enabled: true
        port: {{ .Values.tdarrNetwork.serverPort }}
        nodePort: {{ .Values.tdarrNetwork.serverPort }}
        targetSelector: tdarr-server
{{- end -}}