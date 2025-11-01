{{- define "tdarr.workload" -}}
workload:
  tdarr-server:
    enabled: true
    primary: true
    type: Deployment
    podSpec:
      hostNetwork: false
      containers:
        tdarr-server:
          enabled: true
          primary: true
          imageSelector: image
          securityContext:
            runAsNonRoot: false
            runAsUser: 0
            runAsGroup: 0
            readOnlyRootFilesystem: false
            capabilities:
              add:
                - CHOWN
                - FOWNER
                - SETUID
                - SETGID
          fixedEnv:
            PUID: {{ .Values.tdarrID.user }}
            PGID: {{ .Values.tdarrID.group }}
            UMASK_SET: "002"
          envFrom:
            - configMapRef:
                name: tdarr-server-config
          probes:
            liveness:
              enabled: true
              type: http
              path: /api/v2/status
              port: {{ .Values.tdarrNetwork.webPort }}
            readiness:
              enabled: true
              type: http
              path: /api/v2/status
              port: {{ .Values.tdarrNetwork.webPort }}
            startup:
              enabled: true
              type: http
              path: /api/v2/status
              port: {{ .Values.tdarrNetwork.webPort }}

{{ with .Values.tdarrGPU }}
scaleGPU:
  {{ range $key, $value := . }}
  - gpu:
      {{ $key }}: {{ $value }}
    targetSelector:
      tdarr-server:
        - tdarr-server
  {{ end }}
{{ end }}
{{- end -}}
