{{- define "rustfs.portal" -}}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: portal
data:
  path: "/"
  port: {{ .Values.rustfsNetwork.consolePort | quote }}
  protocol: http
  host: $node_ip
{{- end -}}
