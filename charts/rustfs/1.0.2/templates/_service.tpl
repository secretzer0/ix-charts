{{- define "rustfs.service" -}}
service:
  rustfs:
    enabled: true
    primary: true
    type: NodePort
    targetSelector: rustfs
    ports:
      console:
        enabled: true
        primary: true
        port: {{ .Values.rustfsNetwork.consolePort }}
        nodePort: {{ .Values.rustfsNetwork.consolePort }}
        targetSelector: rustfs
      api:
        enabled: true
        port: {{ .Values.rustfsNetwork.apiPort }}
        nodePort: {{ .Values.rustfsNetwork.apiPort }}
        targetSelector: rustfs
{{- end -}}
