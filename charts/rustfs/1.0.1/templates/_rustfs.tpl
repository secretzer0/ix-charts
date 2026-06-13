{{- define "rustfs.workload" -}}
workload:
  rustfs:
    enabled: true
    primary: true
    type: Deployment
    podSpec:
      hostNetwork: {{ .Values.rustfsNetwork.hostNetwork }}
      containers:
        rustfs:
          enabled: true
          primary: true
          imageSelector: image
          securityContext:
            runAsUser: {{ .Values.rustfsRunAs.user }}
            runAsGroup: {{ .Values.rustfsRunAs.group }}
            readOnlyRootFilesystem: false
          env:
            RUSTFS_ADDRESS: {{ printf ":%v" .Values.rustfsNetwork.apiPort | quote }}
            RUSTFS_CONSOLE_ADDRESS: {{ printf ":%v" .Values.rustfsNetwork.consolePort | quote }}
            RUSTFS_CONSOLE_ENABLE: {{ .Values.rustfsConfig.consoleEnable | quote }}
            RUSTFS_VOLUMES: /data
            {{- with .Values.rustfsConfig.serverDomains }}
            RUSTFS_SERVER_DOMAINS: {{ . | quote }}
            {{- end }}
          envFrom:
            - secretRef:
                name: rustfs-creds
          {{- with .Values.rustfsConfig.additionalEnvs }}
          envList:
            {{- range $env := . }}
            - name: {{ $env.name }}
              value: {{ $env.value | quote }}
            {{- end }}
          {{- end }}
          probes:
            liveness:
              enabled: true
              type: tcp
              port: {{ .Values.rustfsNetwork.apiPort }}
            readiness:
              enabled: true
              type: tcp
              port: {{ .Values.rustfsNetwork.apiPort }}
            startup:
              enabled: true
              type: tcp
              port: {{ .Values.rustfsNetwork.apiPort }}
      initContainers:
      {{- include "ix.v1.common.app.permissions" (dict "containerName" "01-permissions"
                                                        "UID" .Values.rustfsRunAs.user
                                                        "GID" .Values.rustfsRunAs.group
                                                        "mode" "check"
                                                        "type" "install") | nindent 8 }}
{{- end -}}

{{- define "rustfs.configuration" -}}
secret:
  rustfs-creds:
    enabled: true
    data:
      RUSTFS_ACCESS_KEY: {{ .Values.rustfsConfig.accessKey | quote }}
      RUSTFS_SECRET_KEY: {{ .Values.rustfsConfig.secretKey | quote }}
{{- end -}}
