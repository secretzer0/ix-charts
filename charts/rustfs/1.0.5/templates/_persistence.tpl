{{- define "rustfs.persistence" -}}
persistence:
  data:
    enabled: true
    {{- include "rustfs.storage.ci.migration" (dict "storage" .Values.rustfsStorage.data) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.rustfsStorage.data) | nindent 4 }}
    targetSelector:
      rustfs:
        rustfs:
          mountPath: /data
        {{- if and (eq .Values.rustfsStorage.data.type "ixVolume")
                  (not (.Values.rustfsStorage.data.ixVolumeConfig | default dict).aclEnable) }}
        01-permissions:
          mountPath: /mnt/directories/data
        {{- end }}
        {{- if and (eq .Values.rustfsStorage.data.type "hostPath")
                  (not (.Values.rustfsStorage.data.hostPathConfig | default dict).aclEnable) }}
        01-permissions:
          mountPath: /mnt/directories/data
        {{- end }}
  logs:
    enabled: true
    {{- include "rustfs.storage.ci.migration" (dict "storage" .Values.rustfsStorage.logs) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.rustfsStorage.logs) | nindent 4 }}
    targetSelector:
      rustfs:
        rustfs:
          mountPath: /logs
        {{- if and (eq .Values.rustfsStorage.logs.type "ixVolume")
                  (not (.Values.rustfsStorage.logs.ixVolumeConfig | default dict).aclEnable) }}
        01-permissions:
          mountPath: /mnt/directories/logs
        {{- end }}
        {{- if and (eq .Values.rustfsStorage.logs.type "hostPath")
                  (not (.Values.rustfsStorage.logs.hostPathConfig | default dict).aclEnable) }}
        01-permissions:
          mountPath: /mnt/directories/logs
        {{- end }}
  tmp:
    enabled: true
    type: emptyDir
    targetSelector:
      rustfs:
        rustfs:
          mountPath: /tmp

  {{- range $idx, $storage := .Values.rustfsStorage.additionalStorages }}
  {{ printf "rustfs-%v" (int $idx) }}:
    enabled: true
    {{- include "rustfs.storage.ci.migration" (dict "storage" $storage) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" $storage) | nindent 4 }}
    targetSelector:
      rustfs:
        rustfs:
          mountPath: {{ $storage.mountPath }}
        {{- if and (eq $storage.type "ixVolume") (not ($storage.ixVolumeConfig | default dict).aclEnable) }}
        01-permissions:
          mountPath: /mnt/directories{{ $storage.mountPath }}
        {{- end }}
        {{- if and (eq $storage.type "hostPath") (not ($storage.hostPathConfig | default dict).aclEnable) }}
        01-permissions:
          mountPath: /mnt/directories{{ $storage.mountPath }}
        {{- end }}
  {{- end }}
{{- end -}}

{{- define "rustfs.storage.ci.migration" -}}
  {{- $storage := .storage -}}
  {{- if $storage.hostPath -}}
    {{- $_ := set $storage "hostPathConfig" dict -}}
    {{- $_ := set $storage.hostPathConfig "hostPath" $storage.hostPath -}}
  {{- end -}}
{{- end -}}
