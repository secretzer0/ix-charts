{{- define "tdarr.service" -}}
service:
  tdarr-server:
    enabled: true
    primary: true
    type: NodePort
    ports:
      webui:
        enabled: true
        primary: true
        port: {{ .Values.tdarrNetwork.webPort }}
        nodePort: {{ .Values.tdarrNetwork.webPort }}
        targetPort: {{ .Values.tdarrNetwork.webPort }}
      server:
        enabled: true
        port: {{ .Values.tdarrNetwork.serverPort }}
        nodePort: {{ .Values.tdarrNetwork.serverPort }}
        targetPort: {{ .Values.tdarrNetwork.serverPort }}
{{- end -}}
