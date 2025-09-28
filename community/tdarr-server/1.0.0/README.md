# Tdarr-Server Chart

Server-only Tdarr instance with integrated API server for TrueNAS SCALE.

## Overview

This chart deploys Tdarr in **server-only mode** (no internal transcoding node) with:
- API server sidecar for Pro features
- External transcoding coordination script
- Custom Ultimate All-In-One transcoding plugin
- Two-instance architecture support for minimal ZFS fragmentation

## Key Differences from Standard Tdarr Chart

- **Server-only**: No internal transcoding node - relies on remote GPU workers
- **API Server**: Integrated sidecar enables all Pro features without subscription
- **Coordination Script**: Embedded script for arr instance coordination
- **Custom Plugin**: Pre-loaded Ultimate All-In-One plugin in Local section
- **State Management**: Dedicated ixVolume for coordination state files

## Architecture

This chart implements the **server-only** component of a two-instance Tdarr architecture designed to minimize ZFS fragmentation. For complete architecture details, see:

📖 **[docs/TWO_INSTANCE_ARCHITECTURE.md](docs/TWO_INSTANCE_ARCHITECTURE.md)**

## Quick Links

- **[docs/README.md](docs/README.md)** - Architecture overview
- **[docs/CONFIGURATION.md](docs/CONFIGURATION.md)** - Setup and deployment guide
- **[DEPLOYMENT_NOTES.md](DEPLOYMENT_NOTES.md)** - TrueNAS SCALE specific deployment
- **[CHART_DEVELOPMENT.md](CHART_DEVELOPMENT.md)** - Chart template development guide

## Storage Requirements

### TrueNAS-managed (ixVolume)
- Server data
- Configs
- Logs
- State directory (JSON coordination files)

### Shared Storage (NFS/hostpath)
Required for server + remote GPU workers:
- **Transcode Cache** (`/transcodes/cache`) - GPU in-progress files
- **Transcode Movies** (`/transcode/Movies`) - Input from transcode-Radarr
- **Transcode TV** (`/transcode/TV`) - Input from transcode-Sonarr
- **Media Movies** (`/media/Movies`) - Output for archive-Radarr
- **Media TV** (`/media/TV`) - Output for archive-Sonarr

## Deployment

1. Configure NFS shares for transcode cache and media directories
2. Install chart through TrueNAS SCALE Apps
3. Configure storage mounts in chart UI
4. Deploy remote GPU worker nodes pointing to this server
5. Configure Radarr/Sonarr instances per architecture docs

See **[DEPLOYMENT_NOTES.md](DEPLOYMENT_NOTES.md)** for detailed TrueNAS SCALE deployment instructions.

## Components

### Tdarr Server
- Version: 2.45.01
- Mode: Server-only (no internal node)
- Ports: 30028 (UI), 30029 (server)

### API Server
- Python 3.11 Flask sidecar
- Intercepts `api.tdarr.io` calls
- Enables all Pro features
- Self-signed certificate

### Coordination Script
- Mode: transcode-import, tdarr-complete
- State files in `/var/lib/tdarr_state/`
- API coordination with Radarr/Sonarr

### Custom Plugin
- **Tdarr_Plugin_Ultimate_All_In_One.js**
- Pre-loaded in Local plugins section
- Comprehensive transcoding workflow

## Support

For issues or questions:
- Architecture questions: See [docs/TWO_INSTANCE_ARCHITECTURE.md](docs/TWO_INSTANCE_ARCHITECTURE.md)
- Deployment help: See [DEPLOYMENT_NOTES.md](DEPLOYMENT_NOTES.md)
- Chart development: See [CHART_DEVELOPMENT.md](CHART_DEVELOPMENT.md)