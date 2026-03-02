{{- define "zap2xml.workload" -}}
workload:
  zap2xml:
    enabled: true
    primary: true
    type: Deployment
    podSpec:
      hostNetwork: false
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
            - /bin/sh
            - -c
          args:
            - |
              next_cron() {
                node -e "
                  var s = process.env.CRON_SCHEDULE.split(' ');
                  var m = function(f, v) {
                    if (f === '*') return true;
                    if (f.indexOf('*/') === 0) return v % parseInt(f.substring(2)) === 0;
                    return f.split(',').indexOf(String(v)) >= 0;
                  };
                  var d = new Date();
                  d.setSeconds(0, 0);
                  d.setMinutes(d.getMinutes() + 1);
                  for (var i = 0; i < 525600; i++) {
                    if (m(s[0], d.getMinutes()) && m(s[1], d.getHours()) && m(s[2], d.getDate()) && m(s[3], d.getMonth() + 1) && m(s[4], d.getDay())) {
                      console.log(Math.max(1, Math.floor((d.getTime() - Date.now()) / 1000)));
                      process.exit(0);
                    }
                    d.setMinutes(d.getMinutes() + 1);
                  }
                  console.log(3600);
                "
              }
              echo "[$(date)] Running zap2xml on startup..."
              node dist/index.js || echo "[$(date)] Run failed with exit code $?"
              while true; do
                SLEEP=$(next_cron 2>/dev/null)
                case "$SLEEP" in ''|*[!0-9]*) SLEEP=3600 ;; esac
                echo "[$(date)] Next run in ${SLEEP} seconds (schedule: $CRON_SCHEDULE)"
                sleep "$SLEEP"
                echo "[$(date)] Running zap2xml..."
                node dist/index.js || echo "[$(date)] Run failed with exit code $?"
              done
          env:
            OUTPUT_FILE: {{ .Values.zap2xmlConfig.outputFile | quote }}
            LINEUP_ID: {{ .Values.zap2xmlConfig.lineupId | quote }}
            TIMESPAN: {{ .Values.zap2xmlConfig.timespan | quote }}
            POSTAL_CODE: {{ .Values.zap2xmlConfig.postalCode | quote }}
            CRON_SCHEDULE: {{ .Values.zap2xmlConfig.cronSchedule | quote }}
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
