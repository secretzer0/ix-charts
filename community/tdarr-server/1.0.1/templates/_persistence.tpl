{{- define "tdarr.persistence" -}}
persistence:
  server:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.server) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.server.mountPath }}

  configs:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.configs) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.configs.mountPath }}

  logs:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.logs) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.logs.mountPath }}

  temp:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.temp) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.temp.mountPath }}

  {{- if .Values.tdarrStorage.mediaMovies.enabled }}
  media-movies:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.mediaMovies) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.mediaMovies.mountPath }}
  {{- end }}

  {{- if .Values.tdarrStorage.mediaTV.enabled }}
  media-tv:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.mediaTV) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.mediaTV.mountPath }}
  {{- end }}

  {{- if .Values.tdarrStorage.transcodeMovies.enabled }}
  transcode-movies:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.transcodeMovies) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.transcodeMovies.mountPath }}
  {{- end }}

  {{- if .Values.tdarrStorage.transcodeTV.enabled }}
  transcode-tv:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.transcodeTV) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.transcodeTV.mountPath }}
  {{- end }}

  {{- if .Values.tdarrStorage.pluginsLocal.enabled }}
  plugins-local:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.pluginsLocal) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.pluginsLocal.mountPath }}
  {{- end }}

  {{- if .Values.tdarrStorage.pluginsFlow.enabled }}
  plugins-flow:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.pluginsFlow) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.pluginsFlow.mountPath }}
  {{- end }}

  {{- if .Values.tdarrStorage.pluginsFlowTemplates.enabled }}
  plugins-flow-templates:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" .Values.tdarrStorage.pluginsFlowTemplates) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ .Values.tdarrStorage.pluginsFlowTemplates.mountPath }}
  {{- end }}

  {{- range $idx, $storage := .Values.tdarrStorage.additionalStorages }}
  additional-{{ $idx }}:
    enabled: true
    {{- include "ix.v1.common.app.storageOptions" (dict "storage" $storage) | nindent 4 }}
    targetSelector:
      tdarr-server:
        tdarr-server:
          mountPath: {{ $storage.mountPath }}
  {{- end }}
{{- end -}}
