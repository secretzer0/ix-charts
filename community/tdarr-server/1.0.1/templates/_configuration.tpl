{{- define "tdarr-server.configuration" -}}
configmap:
  script:
    enabled: true
    data:
      external.transcoder.script.sh: |
        {{- .Files.Get "scripts/external.transcoder.script.sh" | nindent 8 }}

  plugin:
    enabled: true
    data:
      Tdarr_Plugin_Ultimate_All_In_One.js: |
        {{- .Files.Get "plugins/Tdarr_Plugin_Ultimate_All_In_One.js" | nindent 8 }}

  api-server-app:
    enabled: true
    data:
      app.py: |
        {{- .Files.Get "api-server/app.py" | nindent 8 }}

{{/* ConfigMap mounts for script, plugin, and api-server app */}}
persistence:
  script:
    enabled: true
    type: configmap
    objectName: script
    defaultMode: "0755"
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /opt/scripts/external.transcoder.script.sh
          subPath: external.transcoder.script.sh
          readOnly: true

  plugin:
    enabled: true
    type: configmap
    objectName: plugin
    defaultMode: "0644"
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /app/server/Tdarr/Plugins/Local/Tdarr_Plugin_Ultimate_All_In_One.js
          subPath: Tdarr_Plugin_Ultimate_All_In_One.js
          readOnly: true

  api-server-app:
    enabled: true
    type: configmap
    objectName: api-server-app
    defaultMode: "0644"
    targetSelector:
      tdarr-server:
        api-server:
          mountPath: /app/app.py
          subPath: app.py
          readOnly: true
{{- end -}}

{{- define "tdarr-server.hostsSetup" -}}
01-hosts-setup:
  enabled: true
  type: init
  imageSelector: image
  securityContext:
    runAsUser: 0
    runAsGroup: 0
    readOnlyRootFilesystem: false
    runAsNonRoot: false
    capabilities:
      add:
        - CHOWN
        - FOWNER
  command:
    - /bin/sh
    - -c
    - |
      # Add api.tdarr.io to /etc/hosts for API server interception
      if ! grep -q "api.tdarr.io" /etc/hosts; then
        echo "127.0.0.1 api.tdarr.io" >> /etc/hosts
      fi
{{- end -}}