# Tdarr-Server Deployment Notes for TrueNAS SCALE

Detailed deployment guide for installing and configuring the tdarr-server chart with integrated API server on TrueNAS SCALE.

## Prerequisites

### 1. Network Storage

You need **5 shared network directories** accessible from both:
- TrueNAS SCALE system (tdarr-server)
- Remote GPU worker nodes

Recommended approach: Create NFS shares on TrueNAS SCALE or dedicated NFS server.

**Required Shares**:
- `/mnt/transcode-pool/cache` - Transcode cache (GPU workers write here)
- `/mnt/transcode-pool/Movies` - Transcode Movies queue
- `/mnt/transcode-pool/TV` - Transcode TV queue
- `/mnt/media-pool/Movies` - Final Movies output
- `/mnt/media-pool/TV` - Final TV output

### 2. Radarr/Sonarr Instances

You need **4 arr instances** (see [docs/TWO_INSTANCE_ARCHITECTURE.md](docs/TWO_INSTANCE_ARCHITECTURE.md)):

**Transcode Instances**:
- transcode-Radarr (port 7878)
- transcode-Sonarr (port 8989)

**Archive Instances**:
- archive-Radarr (port 7879)
- archive-Sonarr (port 8990)

### 3. Remote GPU Worker Nodes

At least 1 system with:
- GPU for hardware transcoding
- Docker installed
- Network access to shared storage and tdarr-server

## Installation Steps

### Step 1: Create NFS Shares (if needed)

In TrueNAS SCALE:

1. **Storage** → **Pools** → Create datasets:
   ```
   transcode-pool/
   ├── cache
   ├── Movies
   └── TV

   media-pool/
   ├── Movies
   └── TV
   ```

2. **Sharing** → **Unix (NFS) Shares** → Add 5 shares:
   - Path: `/mnt/transcode-pool/cache`, Hosts: [GPU worker IPs]
   - Path: `/mnt/transcode-pool/Movies`, Hosts: [GPU worker IPs]
   - Path: `/mnt/transcode-pool/TV`, Hosts: [GPU worker IPs]
   - Path: `/mnt/media-pool/Movies`, Hosts: [GPU worker IPs]
   - Path: `/mnt/media-pool/TV`, Hosts: [GPU worker IPs]

### Step 2: Install Tdarr-Server Chart

1. **Apps** → **Available Applications** → Search "tdarr-server"
2. Click **Install**

### Step 3: Configure Application

#### General Configuration

**Timezone**: Select your timezone

**User/Group ID**: Default `568` (apps user)

#### Network Configuration

**Web Port**: `30028` (Tdarr UI)
**Server Port**: `30029` (Node communication)

#### Storage Configuration

**TrueNAS-Managed Volumes** (auto-created):
- ✅ Server Data
- ✅ Configs
- ✅ Logs
- ✅ State Directory

**Transcode Cache** (NFS/hostPath):
- Type: `Host Path`
- Path: `/mnt/transcode-pool/cache` (or your NFS mount point)

**Transcode Movies**:
- Type: `Host Path`
- Path: `/mnt/transcode-pool/Movies`

**Transcode TV**:
- Type: `Host Path`
- Path: `/mnt/transcode-pool/TV`

**Media Movies**:
- Type: `Host Path`
- Path: `/mnt/media-pool/Movies`

**Media TV**:
- Type: `Host Path`
- Path: `/mnt/media-pool/TV`

#### Resources

**CPU**: `4000m` (4 cores)
**Memory**: `8Gi` (8GB)

Adjust based on library size and concurrent worker count.

### Step 4: Deploy Application

Click **Install** and wait for deployment:

```
Status: Deploying... → Active
```

### Step 5: Access Tdarr UI

1. **Apps** → **Installed** → Click tdarr-server **Web Portal** button
2. URL: `http://[truenas-ip]:30028`

### Step 6: Verify API Server

In Tdarr UI:
1. **Settings** → **License**
2. Should show **Pro features enabled** without entering license key
3. If not working, check pod logs (see Troubleshooting below)

### Step 7: Verify Plugin Availability

1. **Plugins** → **Local**
2. Should see **Tdarr_Plugin_Ultimate_All_In_One**
3. If not visible, check ConfigMap mount (see Troubleshooting)

### Step 8: Configure Remote GPU Workers

On each GPU worker machine:

```bash
docker run -d \
  --name tdarr-node \
  --restart unless-stopped \
  --network host \
  --gpus all \
  -v /mnt/transcode-pool/cache:/temp \
  -v /mnt/transcode-pool/Movies:/transcode/Movies:ro \
  -v /mnt/transcode-pool/TV:/transcode/TV:ro \
  -v /mnt/media-pool/Movies:/media/Movies \
  -v /mnt/media-pool/TV:/media/TV \
  -v /opt/tdarr/configs:/app/configs \
  -v /opt/tdarr/logs:/app/logs \
  -e NODE_NAME="GPU-Worker-01" \
  -e SERVER_IP="[truenas-ip]" \
  -e SERVER_PORT="30029" \
  -e PUID=568 \
  -e PGID=568 \
  haveagitgat/tdarr_node:2.45.01
```

Replace:
- `[truenas-ip]`: TrueNAS SCALE IP address
- `GPU-Worker-01`: Unique name for this worker
- Mount paths: Adjust if using different NFS mount points

### Step 9: Verify Worker Connection

In Tdarr UI:
1. **Nodes** tab
2. Should see worker(s) listed as **Online**
3. Check GPU detection and health metrics

### Step 10: Configure Tdarr Libraries

1. **Libraries** → **+** Add Library
2. **Source**: `/transcode/Movies` or `/transcode/TV`
3. **Transcode Cache**: `/temp`
4. **Folder Watch**: Enabled
5. **Flows**: Create transcode flow using Ultimate All-In-One plugin

### Step 11: Configure Radarr/Sonarr Integration

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for detailed arr configuration:

**Transcode-Radarr**:
- Root folder: `/transcode/Movies`
- Download client: Points to your download client
- Connect script: Triggers on import

**Archive-Radarr**:
- Root folder: `/media/Movies`
- Import from: `/media/Movies` (manual import or script-triggered)

## Coordination Script Usage

The embedded `external.transcoder.script.sh` coordinates between arr instances.

### Script Modes

**Mode 1: transcode-import** (triggered by transcode-Radarr/Sonarr):
```bash
/opt/scripts/external.transcoder.script.sh transcode-import \
  --type [movie|tv] \
  --file "[path]" \
  --imdb "[id]" \
  --tmdb "[id]"
```

Creates state file → Tdarr picks up for transcoding

**Mode 2: tdarr-complete** (triggered by Tdarr):
```bash
/opt/scripts/external.transcoder.script.sh tdarr-complete \
  --type [movie|tv] \
  --file "[path]"
```

Moves file → Triggers archive-Radarr/Sonarr import

### Radarr/Sonarr Connect Script Configuration

In transcode-Radarr/Sonarr:
1. **Settings** → **Connect** → **+** → **Custom Script**
2. **On Import**: ✅
3. **Path**: `/path/to/wrapper-script.sh` (creates container-accessible wrapper)
4. Script calls tdarr-server container:
   ```bash
   kubectl exec -n ix-tdarr-server [pod-name] -- \
     /opt/scripts/external.transcoder.script.sh transcode-import \
     --type movie \
     --file "$sonarr_episodefile_path" \
     --imdb "$sonarr_movie_imdbid"
   ```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n ix-tdarr-server
```

Should show:
```
NAME                            READY   STATUS
tdarr-server-[hash]             2/2     Running
```

`2/2` means both containers (tdarr-server + api-server) running.

### View Logs

**Tdarr-Server logs**:
```bash
kubectl logs -n ix-tdarr-server [pod-name] -c tdarr-server
```

**API Server logs**:
```bash
kubectl logs -n ix-tdarr-server [pod-name] -c api-server
```

**Init container logs** (if pod won't start):
```bash
kubectl logs -n ix-tdarr-server [pod-name] -c 01-hosts-setup
```

### Common Issues

#### API Server Not Working

**Symptom**: Tdarr shows "Pro features disabled"

**Check**:
1. API server container running:
   ```bash
   kubectl logs -n ix-tdarr-server [pod-name] -c api-server
   ```
2. Should see: `Running on https://0.0.0.0:443`

**Fix**: Restart pod if Flask install failed:
```bash
kubectl delete pod -n ix-tdarr-server [pod-name]
```

#### Plugin Not Visible

**Symptom**: Ultimate All-In-One plugin not in Local section

**Check** ConfigMap:
```bash
kubectl get configmap tdarr-server-plugin -n ix-tdarr-server -o yaml
```

**Fix**: Rebuild chart if ConfigMap missing (see CHART_DEVELOPMENT.md)

#### Workers Can't Connect

**Symptom**: Workers show "Offline" in Tdarr UI

**Check**:
1. Network connectivity: `ping [truenas-ip]` from worker
2. Port accessibility: `nc -zv [truenas-ip] 30029`
3. Firewall rules on TrueNAS SCALE

**Fix**: Open port 30029 in TrueNAS firewall if needed

#### Storage Mount Permission Denied

**Symptom**: Tdarr can't read/write NFS mounts

**Check** mount permissions:
```bash
kubectl exec -n ix-tdarr-server [pod-name] -c tdarr-server -- ls -la /transcode/Movies
```

**Fix**:
1. Ensure NFS exports allow access from TrueNAS IP
2. Set NFS export permissions: `mapall=568:568` (apps user)

#### State Files Not Persisting

**Symptom**: Script loses coordination state after pod restart

**Check** state volume:
```bash
kubectl exec -n ix-tdarr-server [pod-name] -c tdarr-server -- ls -la /var/lib/tdarr_state
```

**Fix**: Verify ixVolume created:
```bash
kubectl get pvc -n ix-tdarr-server
```

## Upgrade Procedure

### Upgrading Tdarr Version

1. Stop all remote GPU workers
2. In TrueNAS: **Apps** → **Installed** → tdarr-server → **Edit**
3. Chart will auto-create snapshot before upgrade
4. Update application version if new chart available
5. **Save** and wait for redeployment
6. Restart GPU workers with new image version

### Rollback

If upgrade fails:
1. **Apps** → **Installed** → tdarr-server → **Roll Back**
2. Select previous version from snapshot list
3. **Restore**

## Performance Tuning

### Resource Allocation

Adjust based on:
- **Library size**: Larger = more CPU/memory
- **Worker count**: More workers = more server load
- **Concurrent transcodes**: More = more cache I/O

**Light usage** (1-2 workers, small library):
- CPU: 2000m (2 cores)
- Memory: 4Gi

**Heavy usage** (5+ workers, large library):
- CPU: 8000m (8 cores)
- Memory: 16Gi

### Storage Performance

**Transcode Cache**:
- Use SSD/NVMe for best performance
- Size: 2-3x largest video file
- RAID configuration with good random I/O

**Network Bandwidth**:
- Gigabit minimum for HD content
- 10GbE recommended for 4K content
- Consider dedicated VLAN for media traffic

## Monitoring

### Health Checks

**Tdarr UI** → **System** tab shows:
- Server uptime
- Worker status
- Queue depth
- Transcode statistics

### System Monitoring

Monitor TrueNAS:
- **Dashboard** → CPU/Memory usage
- **Storage** → Dataset I/O statistics
- **Network** → Interface traffic

### Log Monitoring

Key log locations:
- Tdarr logs: ixVolume dataset `/logs`
- Worker logs: Each worker's `/app/logs`
- Script logs: Check state directory for debug output

## Security Considerations

### API Server

- Runs on localhost only (not exposed externally)
- Self-signed certificate (insecure but acceptable for local use)
- No actual license key stored or transmitted

### Network Security

- Limit NFS exports to known worker IPs
- Use firewall rules to restrict port 30029 to worker subnet
- Consider VPN if workers on different networks

### File Permissions

- All files owned by `568:568` (apps user)
- Script executable but not writable by Tdarr process
- State files readable/writable by Tdarr only

## Support

For additional help:
- Architecture questions: [docs/TWO_INSTANCE_ARCHITECTURE.md](docs/TWO_INSTANCE_ARCHITECTURE.md)
- Chart development: [CHART_DEVELOPMENT.md](CHART_DEVELOPMENT.md)
- TrueNAS SCALE docs: https://www.truenas.com/docs/scale/
- Tdarr docs: https://docs.tdarr.io/