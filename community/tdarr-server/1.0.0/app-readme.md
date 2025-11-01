# Tdarr Server

Tdarr is a distributed transcoding application that automates media library transcoding and remuxing. This chart deploys the Tdarr Server (primary node) optimized for local filesystem access.

## Use Case

This chart is designed for scenarios where:

- The Tdarr primary node has **direct access to the local filesystem** (no NFS overhead)
- Remote worker nodes connect to this server via NFS or network shares
- Media files are stored on the same system as the Tdarr server
- Transcoding output can be written directly to local storage without network copy operations

## Key Features

- **Tdarr Server**: Always runs the server and web UI for managing transcoding jobs
- **Optional Internal Node**: Can optionally run a worker node alongside the server
- **Predefined Media Mounts**: Convenient configuration for Movies and TV libraries
- **Predefined Transcode Storage**: Separate mount points for transcoded output
- **Plugin Support**: Optional mounts for custom Tdarr plugins and Flow plugins
- **Flexible Additional Storage**: Support for custom mount points beyond predefined ones

## Deployment Architecture

### Recommended Setup

1. **Primary Node (this chart)**: Deploy on the system with direct filesystem access
   - Enable internal node if the server has GPU/CPU resources for transcoding
   - Mount media libraries using local paths (e.g., `/mnt/media/Movies`)
   - Mount transcode cache to local fast storage

2. **Worker Nodes** (use standard `tdarr` chart or external nodes):
   - Connect to this server via the server port (default: 8266)
   - Access media via NFS/SMB mounts
   - Configure with `serverIP` pointing to this primary node

### Storage Configuration

**Core Storage** (always required):
- `/app/server` - Server database and state
- `/app/configs` - Application configuration
- `/app/logs` - Application logs
- `/temp` - Temporary transcode cache

**Media Libraries** (optional):
- `/media/Movies` - Movies library mount
- `/media/TV` - TV shows library mount

**Transcode Storage** (optional):
- `/transcode/Movies` - Movies transcode output
- `/transcode/TV` - TV shows transcode output

**Plugin Storage** (optional):
- `/app/server/Tdarr/Plugins/Local` - Custom plugins
- `/app/server/Tdarr/Plugins/FlowPlugins/LocalFlowPlugins` - Flow plugins
- `/app/server/Tdarr/Plugins/FlowPlugins/LocalFlowTemplates` - Flow templates

**Additional Storage**: Configure any custom mount points as needed

## Network Ports

- **8265** (default): Web UI - Access the Tdarr interface
- **8266** (default): Server port - Worker nodes connect here

## Performance Benefits

By running the primary node with direct filesystem access:

- **Faster file moves**: Final transcoded files can be moved instantly on the same filesystem
- **Reduced network load**: No NFS transfer overhead for server database operations
- **Lower latency**: Direct I/O to storage instead of network round-trips
- **Better reliability**: No dependency on network stability for server operations

## Getting Started

1. Configure the network ports (defaults work for most setups)
2. Enable and configure media library mounts (Movies, TV)
3. Enable and configure transcode storage mounts
4. Optionally enable internal node if you want the server to also transcode
5. Configure GPU allocation if using internal node with hardware acceleration
6. Deploy and access the web UI at `http://<node-ip>:8265`

## Connecting Worker Nodes

To connect external worker nodes to this server:

1. Deploy worker nodes using the standard `tdarr` chart with internal node disabled, or use external Tdarr node installations
2. Configure worker node with:
   - `serverIP`: IP address of this primary node
   - `serverPort`: 8266 (or your configured server port)
3. Ensure worker nodes can access media via NFS/SMB mounts at the same paths as the server

## Documentation

For more information about Tdarr:
- Official Website: https://tdarr.io/
- Documentation: https://docs.tdarr.io/
- GitHub: https://github.com/HaveAGitGat/Tdarr
