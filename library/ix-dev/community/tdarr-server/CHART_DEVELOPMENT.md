# Tdarr-Server Chart Development Guide

Guide for developers working on the tdarr-server Helm chart for TrueNAS SCALE.

## Chart Structure

```
tdarr-server/
├── Chart.yaml                 # Chart metadata and dependencies
├── values.yaml                # Default configuration values
├── questions.yaml             # TrueNAS UI form definitions
├── item.yaml                  # Catalog item metadata
├── app-readme.md              # User-facing description
├── README.md                  # This chart's overview
├── CHART_DEVELOPMENT.md       # This file
├── DEPLOYMENT_NOTES.md        # Deployment guide
├── docs/                      # Architecture documentation
│   ├── README.md
│   ├── TWO_INSTANCE_ARCHITECTURE.md
│   ├── CONFIGURATION.md
│   └── IMPLEMENTATION_SUMMARY.md
├── scripts/
│   └── external.transcoder.script.sh
├── plugins/
│   └── Tdarr_Plugin_Ultimate_All_In_One.js
├── api-server/
│   ├── app.py
│   ├── requirements.txt
│   └── README.md
└── templates/
    ├── common.yaml            # Template loader
    ├── _tdarr-server.tpl      # Main workload definition
    ├── _api-server.tpl        # Sidecar container
    ├── _configuration.tpl     # ConfigMaps and init containers
    ├── _persistence.tpl       # Storage volumes
    ├── _service.tpl           # Network services
    └── _portal.tpl            # TrueNAS portal button
```

## TrueNAS SCALE Chart Patterns

### Common Library Dependency

All charts depend on `/library/common` (v1.2.9) which provides:
- Standardized Kubernetes resource templates
- TrueNAS-specific helpers
- Consistent patterns for workloads, storage, networking

### Template Pattern

TrueNAS charts use a merge-based pattern:

1. **Define configuration** in separate `_*.tpl` files
2. **Merge into Values** using `mustMergeOverwrite`
3. **Apply via common loader** with `ix.v1.common.loader.apply`

Example from `common.yaml`:
```yaml
{{- $_ := mustMergeOverwrite .Values (include "tdarr-server.workload" $ | fromYaml) -}}
{{- $_ := mustMergeOverwrite .Values (include "tdarr-server.service" $ | fromYaml) -}}
{{- include "ix.v1.common.loader.apply" . -}}
```

### Multi-Container Workload

This chart runs 2 containers in a single pod:

**Primary Container** (`tdarr-server`):
- Main Tdarr server application
- Port 8265 (UI), 8266 (server)
- Server-only mode (`internalNode: false`)

**Sidecar Container** (`api-server`):
- Flask API intercepting api.tdarr.io
- Port 443 with self-signed cert
- Shares pod network namespace with primary

### Init Containers

**Purpose**: Run before main containers start

This chart uses init containers for:
1. **/etc/hosts modification**: Add `127.0.0.1 api.tdarr.io` entry
2. **Permissions**: Ensure correct ownership on mounted volumes

### ConfigMaps

Used to inject file content into containers:

**Script ConfigMap**:
- Source: `scripts/external.transcoder.script.sh`
- Mount: `/opt/scripts/external.transcoder.script.sh`
- Mode: 0755 (executable)

**Plugin ConfigMap**:
- Source: `plugins/Tdarr_Plugin_Ultimate_All_In_One.js`
- Mount: `/app/server/Tdarr/Plugins/Local/Tdarr_Plugin_Ultimate_All_In_One.js`

**API Server App ConfigMap**:
- Source: `api-server/app.py`
- Mount: `/app/app.py`

## Template Development

### _tdarr-server.tpl

Defines the main workload with 2 containers:

```yaml
workload:
  tdarr-server:
    enabled: true
    primary: true
    type: Deployment
    podSpec:
      containers:
        tdarr-server:           # Primary container
          enabled: true
          primary: true
          imageSelector: image
          # ... container config
        api-server:             # Sidecar container
          enabled: true
          primary: false
          imageSelector: apiServerImage
          # ... sidecar config
      initContainers:
        01-hosts-setup:         # /etc/hosts modification
          # ... init container config
```

### _api-server.tpl

Sidecar container configuration:

```yaml
api-server:
  enabled: true
  primary: false
  imageSelector: apiServerImage
  command:
    - /bin/sh
    - -c
    - |
      pip install --no-cache-dir Flask==3.0.0 Werkzeug==3.0.1 pyOpenSSL==24.0.0
      python /app/app.py
  probes:
    liveness:
      enabled: false
    readiness:
      enabled: false
```

### _configuration.tpl

ConfigMaps and init container definitions:

```yaml
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
{{- end -}}
```

### _persistence.tpl

Storage volume definitions:

```yaml
persistence:
  server:
    enabled: true
    type: ixVolume
    datasetName: server
    mountPath: /server

  transcode-cache:
    enabled: true
    type: {{ .Values.tdarrStorage.transcodeCache.type }}
    {{- if eq .Values.tdarrStorage.transcodeCache.type "hostPath" }}
    hostPath: {{ .Values.tdarrStorage.transcodeCache.hostPath }}
    {{- end }}
    mountPath: /transcodes/cache

  state:
    enabled: true
    type: ixVolume
    datasetName: state
    mountPath: /var/lib/tdarr_state
```

## questions.yaml Schema

TrueNAS UI form definitions with validation:

### Field Types

- `string`: Text input
- `int`: Number input
- `boolean`: Checkbox
- `list`: Array of items
- `dict`: Nested object with `attrs`
- `hostpath`: Path picker for host filesystem
- `path`: Generic path input

### $ref System

Pull system data into dropdowns:

```yaml
- variable: TZ
  schema:
    type: string
    $ref:
      - definitions/timezone    # System timezone list
```

Available refs:
- `definitions/timezone`
- `definitions/interface`
- `definitions/gpuConfiguration`

### Conditional Display

Show fields based on other values:

```yaml
- variable: nodeName
  schema:
    type: string
    show_if: [["internalNode", "=", true]]
```

### Storage Configuration

**ixVolume** (TrueNAS-managed):
```yaml
- variable: server
  schema:
    type: dict
    attrs:
      - variable: type
        schema:
          type: string
          default: "ixVolume"
      - variable: ixVolumeConfig
        schema:
          type: dict
          attrs:
            - variable: datasetName
              schema:
                type: string
```

**hostPath** (NFS/network share):
```yaml
- variable: transcodeCache
  schema:
    type: dict
    attrs:
      - variable: type
        schema:
          type: string
          default: "hostPath"
      - variable: hostPath
        schema:
          type: hostpath
          required: true
```

## Build and Test Workflow

### 1. Modify Source Files

Work in `/library/ix-dev/community/tdarr-server/`:
- Modify templates in `templates/`
- Update `values.yaml` defaults
- Adjust `questions.yaml` UI

### 2. Build Chart

```bash
cd /home/tmelhiser/Desktop/ix-charts
./create_app.sh community tdarr-server
```

This creates:
- `/community/tdarr-server/1.0.0/` (production chart)
- Processes templates and creates final Chart.yaml

### 3. Validate

```bash
docker run --rm -v $(pwd):/data ixsystems/catalog_validation:latest \
  validate --path /data
```

### 4. Test Deployment

Deploy in TrueNAS SCALE:
1. Refresh catalog
2. Install tdarr-server app
3. Configure storage mounts
4. Test functionality

## Debugging

### View Generated Kubernetes Resources

```bash
helm template /community/tdarr-server/1.0.0/
```

### Check ConfigMap Content

```bash
kubectl get configmap -n ix-tdarr-server
kubectl get configmap [name] -o yaml -n ix-tdarr-server
```

### View Pod Logs

```bash
kubectl logs -n ix-tdarr-server [pod-name] -c tdarr-server
kubectl logs -n ix-tdarr-server [pod-name] -c mock-license-server
```

### Exec into Container

```bash
kubectl exec -it -n ix-tdarr-server [pod-name] -c tdarr-server -- /bin/sh
```

## Common Issues

### ConfigMap Too Large

If files exceed ConfigMap size limit, consider:
- Using external storage mount instead
- Splitting into multiple ConfigMaps
- Compressing content

### Init Container Failures

Check init container logs:
```bash
kubectl logs -n ix-tdarr-server [pod-name] -c 01-hosts-setup
```

### Sidecar Not Starting

Check if Flask deps install successfully:
```bash
kubectl logs -n ix-tdarr-server [pod-name] -c mock-license-server
```

## Version Management

### Incrementing Chart Version

In `Chart.yaml`:
```yaml
version: 1.0.1      # Chart version (increment for changes)
appVersion: 2.45.01  # Tdarr application version
```

Chart version follows semver:
- **Patch** (1.0.x): Bug fixes, minor changes
- **Minor** (1.x.0): New features, backward compatible
- **Major** (x.0.0): Breaking changes

## References

- [TrueNAS Charts Development](https://github.com/truenas/charts)
- [Common Library Docs](../../../common/README.md)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)