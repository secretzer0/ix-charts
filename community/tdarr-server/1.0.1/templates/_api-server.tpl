{{- define "tdarr-server.apiServer" -}}
api-server:
  enabled: true
  primary: false
  imageSelector: apiServerImage
  securityContext:
    runAsUser: 0
    runAsGroup: 0
    readOnlyRootFilesystem: false
    runAsNonRoot: false
  command:
    - /bin/sh
    - -c
    - |
      pip install --no-cache-dir Flask==3.0.0 Werkzeug==3.0.1 pyOpenSSL==24.0.0
      python /app/app.py
  probes:
    liveness:
      enabled: false
    readiness:
      enabled: false
    startup:
      enabled: false
{{- end -}}