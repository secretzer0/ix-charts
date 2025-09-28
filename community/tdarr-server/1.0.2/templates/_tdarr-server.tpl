{{- define "tdarr-server.workload" -}}
workload:
  tdarr-server:
    enabled: true
    primary: true
    type: Deployment
    podSpec:
      hostNetwork: false
      securityContext:
        fsGroup: {{ .Values.tdarrID.group }}
      initContainers:
        {{- include "tdarr-server.hostsSetup" . | nindent 8 }}
      containers:
        tdarr-server:
          enabled: true
          primary: true
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
                - SETUID
                - SETGID
          env:
            inContainer: "true"
            internalNode: {{ .Values.tdarrConfig.internalNode | quote }}
            serverPort: {{ .Values.tdarrNetwork.serverPort }}
            webUIPort: {{ .Values.tdarrNetwork.webPort }}
            nodeName: {{ .Values.tdarrConfig.nodeName }}
            serverIP: {{ .Values.tdarrConfig.serverIP }}
          fixedEnv:
            PUID: {{ .Values.tdarrID.user }}
          {{ with .Values.tdarrConfig.additionalEnvs }}
          envList:
            {{ range $env := . }}
            - name: {{ $env.name }}
              value: {{ $env.value }}
            {{ end }}
          {{ end }}
          probes:
            liveness:
              enabled: true
              type: http
              port: "{{ .Values.tdarrNetwork.webPort }}"
              path: /api/v2/status
            readiness:
              enabled: true
              type: http
              port: "{{ .Values.tdarrNetwork.webPort }}"
              path: /api/v2/status
            startup:
              enabled: true
              type: http
              port: "{{ .Values.tdarrNetwork.webPort }}"
              path: /api/v2/status
        {{- include "tdarr-server.apiServer" . | nindent 8 }}
{{- end -}}