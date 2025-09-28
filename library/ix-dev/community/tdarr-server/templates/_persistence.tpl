{{- define "tdarr-server.persistence" -}}
persistence:
  server:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" .Values.tdarrStorage.server) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.server) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /app/server
        api-server:
          mountPath: /server

  configs:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" .Values.tdarrStorage.configs) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.configs) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /app/configs

  logs:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" .Values.tdarrStorage.logs) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.logs) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /app/logs

  state:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" .Values.tdarrStorage.state) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.state) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /var/lib/tdarr_state

  transcode-cache:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" .Values.tdarrStorage.transcodeCache) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.transcodeCache) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /transcodes/cache

  transcode-movies:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" .Values.tdarrStorage.transcodeMovies) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.transcodeMovies) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /transcode/Movies

  transcode-tv:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" .Values.tdarrStorage.transcodeTV) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.transcodeTV) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /transcode/TV

  media-movies:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" .Values.tdarrStorage.mediaMovies) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.mediaMovies) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /media/Movies

  media-tv:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" .Values.tdarrStorage.mediaTV) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.mediaTV) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: /media/TV

  {{- range $idx, $storage := .Values.tdarrStorage.additionalStorages }}
  {{ printf "tdarr-server-%v" (int $idx) }}:
    enabled: true
    {{- include "tdarr-server.storage.ci.migration" (dict "storage" $storage) }}
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" $storage) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ $storage.mountPath }}
  {{- end }}
{{- end -}}

{{/* TODO: Remove on the next version bump, eg 1.1.0+ */}}
{{- define "tdarr-server.storage.ci.migration" -}}
  {{- $storage := .storage -}}

  {{- if $storage.hostPath -}}
    {{- $_ := set $storage "hostPathConfig" dict -}}
    {{- $_ := set $storage.hostPathConfig "hostPath" $storage.hostPath -}}
  {{- end -}}
{{- end -}}