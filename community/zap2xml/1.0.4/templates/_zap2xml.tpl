{{- define "zap2xml.workload" -}}
workload:
  zap2xml:
    enabled: true
    primary: true
    type: CronJob
    schedule: {{ .Values.zap2xmlConfig.cronSchedule | quote }}
    concurrencyPolicy: Forbid
    podSpec:
      hostNetwork: false
      restartPolicy: Never
      tolerations:
        - key: "node-role.kubernetes.io/control-plane"
          operator: "Exists"
          effect: "NoSchedule"
        - key: "node-role.kubernetes.io/master"
          operator: "Exists"
          effect: "NoSchedule"
      containers:
        zap2xml:
          enabled: true
          primary: true
          imageSelector: image
          securityContext:
            runAsUser: {{ .Values.zap2xmlRunAs.user }}
            runAsGroup: {{ .Values.zap2xmlRunAs.group }}
          command:
            - node
          args:
            - dist/index.js
          env:
            OUTPUT_FILE: {{ .Values.zap2xmlConfig.outputFile | quote }}
            LINEUP_ID: {{ .Values.zap2xmlConfig.lineupId | quote }}
            TIMESPAN: {{ .Values.zap2xmlConfig.timespan | quote }}
            POSTAL_CODE: {{ .Values.zap2xmlConfig.postalCode | quote }}
          {{ with .Values.zap2xmlConfig.additionalEnvs }}
          envList:
            {{ range $env := . }}
            - name: {{ $env.name }}
              value: {{ $env.value }}
            {{ end }}
          {{ end }}
          probes:
            liveness:
              enabled: false
            readiness:
              enabled: false
            startup:
              enabled: false
      initContainers:
      {{- include "ix.v1.common.app.permissions" (dict
        "containerName" "01-permissions"
        "UID" (include "ix.v1.common.helper.makeIntOrNoop" .Values.zap2xmlRunAs.user)
        "GID" (include "ix.v1.common.helper.makeIntOrNoop" .Values.zap2xmlRunAs.group)
        "mode" "check"
        "type" "install") | nindent 8 }}

{{/* Service - disabled for background service */}}
service:
  zap2xml:
    enabled: false
    primary: true
    type: ClusterIP
    targetSelector: zap2xml
    ports:
      dummy:
        enabled: false
        primary: true
        port: 1
        targetPort: 1
        targetSelector: zap2xml

{{/* Persistence */}}
persistence:
  xmltv:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.zap2xmlStorage.xmltv) | nindent 4 }}
    targetSelector:
      zap2xml:
        zap2xml:
          mountPath: /xmltv
        {{- if and (eq .Values.zap2xmlStorage.xmltv.type "ixVolume")
                  (not (.Values.zap2xmlStorage.xmltv.ixVolumeConfig | default dict).aclEnable) }}
        01-permissions:
          mountPath: /mnt/directories/xmltv
        {{- end }}
  tmp:
    enabled: true
    type: emptyDir
    targetSelector:
      zap2xml:
        zap2xml:
          mountPath: /tmp
  {{- range $idx, $storage := .Values.zap2xmlStorage.additionalStorages }}
  {{ printf "zap2xml-%v:" (int $idx) }}
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" $storage) | nindent 4 }}
    targetSelector:
      zap2xml:
        zap2xml:
          mountPath: {{ $storage.mountPath }}
  {{- end }}
{{- end -}}
