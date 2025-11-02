# Tdarr Server

Tdarr Server chart for TrueNAS SCALE - Primary node optimized for local filesystem access.

## Technical Overview

This chart deploys Tdarr Server (primary node) using the `ghcr.io/haveagitgat/tdarr` container image. It is designed for deployments where the primary node has direct access to local storage, avoiding NFS overhead for server operations and final file placement.

## Chart Details

- **Application Version**: 2.45.01
- **Chart Version**: 1.0.0
- **Container Image**: ghcr.io/haveagitgat/tdarr:2.45.01
- **Deployment Type**: Kubernetes Deployment
- **Service Type**: NodePort
- **Common Library**: 1.2.9

## Architecture

### Workload Configuration

- **Type**: Deployment (single replica)
- **Security Context**:
  - Runs as root (UID 0, GID 0) - required by Tdarr container
  - Capabilities: CHOWN, FOWNER, SETUID, SETGID
  - Container spawns sub-processes with configured PUID/PGID (default: 568)
- **Network**: Container network (no host networking)
- **Health Probes**: HTTP GET to `/api/v2/status` on web UI port

### Storage Architecture

The chart implements a hybrid storage approach:

1. **Core Volumes** (required, default: ixVolume):
   - `server` → `/app/server` - Server database
   - `configs` → `/app/configs` - Configuration files
   - `logs` → `/app/logs` - Application logs
   - `temp` → `/temp` - Transcode cache

2. **Predefined Media Volumes** (optional, default: hostPath):
   - `mediaMovies` → `/media/Movies`
   - `mediaTV` → `/media/TV`

3. **Predefined Transcode Volumes** (optional, default: hostPath):
   - `transcodeMovies` → `/transcode/Movies`
   - `transcodeTV` → `/transcode/TV`

4. **Predefined Plugin Volumes** (optional, default: hostPath):
   - `pluginsLocal` → `/app/server/Tdarr/Plugins/Local`
   - `pluginsFlow` → `/app/server/Tdarr/Plugins/FlowPlugins/LocalFlowPlugins`
   - `pluginsFlowTemplates` → `/app/server/Tdarr/Plugins/FlowPlugins/LocalFlowTemplates`

5. **Additional Storage** (flexible array):
   - User-defined mount points with configurable paths

All volumes support both ixVolume (TrueNAS datasets) and hostPath types.

### Environment Variables

The chart configures the following environment variables:

- `NODE_TLS_REJECT_UNAUTHORIZED=0` - Allow self-signed certificates
- `TZ` - System timezone (from TrueNAS)
- `PUID`, `PGID` - User/group IDs (default: 568)
- `UMASK_SET=002` - File creation mask
- `serverIP` - Server bind address (default: 0.0.0.0)
- `serverPort` - Server communication port (default: 8266)
- `webUIPort` - Web interface port (default: 8265)
- `inContainer=true` - Indicates container environment
- `ffmpegVersion` - FFmpeg version to use (6 or 7, default: 7)
- `internalNode` - Enable/disable internal worker node (default: true)
- `nodeName` - Name for internal node (if enabled)

### Network Configuration

**Services:**
- `webui` (primary): NodePort on 8265 (default)
- `server`: NodePort on 8266 (default)

**Portal Integration:**
- TrueNAS portal button configured for web UI access
- Protocol: HTTP
- Path: `/`

### GPU Support

Optional GPU allocation using TrueNAS common library patterns:
- Supports NVIDIA and Intel GPUs
- Configured via `tdarrGPU` dictionary
- Applied to the tdarr-server container when configured

### Resource Limits

**Defaults:**
- CPU: 4000m (4 cores)
- Memory: 8Gi

Configurable via TrueNAS UI with validation.

## Differences from Standard Tdarr Chart

This chart differs from the standard `tdarr` community chart:

1. **Storage Focus**: Predefined media/transcode volumes optimized for local filesystem access
2. **Use Case**: Designed for primary nodes with direct storage access, not NFS-based deployments
3. **Configuration**: Simplified setup for common media server layouts (Movies/TV structure)
4. **Plugin Support**: Built-in mount points for custom plugins and Flow plugins
5. **Name**: Distinct chart name (`tdarr-server`) to allow side-by-side deployment

## Deployment Scenarios

### Scenario 1: Primary + Remote Workers

**Primary Node (this chart)**:
- Deploy on TrueNAS with direct access to media storage
- Enable internal node if server has GPU/CPU for transcoding
- Mount media and transcode directories using local paths

**Worker Nodes** (standard tdarr chart or external):
- Connect via serverIP:serverPort
- Access media via NFS/SMB
- Handle distributed transcoding

### Scenario 2: Server-Only

**Primary Node (this chart)**:
- Disable internal node
- Pure server/orchestration role
- All transcoding handled by external nodes

## Upgrade Notes

### Version 1.0.0

Initial release:
- Based on Tdarr 2.45.01
- FFmpeg 7 default
- Hybrid storage architecture
- Full plugin mount support

## Configuration Examples

### Basic Setup with Movies and TV

```yaml
tdarrStorage:
  mediaMovies:
    enabled: true
    type: hostPath
    hostPathConfig:
      hostPath: /mnt/media/Movies
  mediaTV:
    enabled: true
    type: hostPath
    hostPathConfig:
      hostPath: /mnt/media/TV
  transcodeMovies:
    enabled: true
    type: hostPath
    hostPathConfig:
      hostPath: /mnt/transcode/Movies
  transcodeTV:
    enabled: true
    type: hostPath
    hostPathConfig:
      hostPath: /mnt/transcode/TV
```

### Server-Only Mode (No Internal Worker)

```yaml
tdarrConfig:
  internalNode: false
```

### With Custom Plugins

```yaml
tdarrStorage:
  pluginsLocal:
    enabled: true
    type: hostPath
    hostPathConfig:
      hostPath: /mnt/appdata/tdarr/plugins
```

## Validation

The chart can be validated using:

```bash
# Build the chart
./create_app.sh community tdarr-server

# Lint the chart
helm lint community/tdarr-server/1.0.0 --values community/tdarr-server/1.0.0/ix_values.yaml
```

## References

- Tdarr: https://tdarr.io/
- Tdarr GitHub: https://github.com/HaveAGitGat/Tdarr
- TrueNAS SCALE: https://www.truenas.com/truenas-scale/
- ix-charts: https://github.com/truenas/charts
