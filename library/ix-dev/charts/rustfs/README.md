# RustFS Chart

S3-compatible object storage server (https://github.com/rustfs/rustfs) packaged for TrueNAS SCALE.

## Configuration

| Parameter | Default | Notes |
|---|---|---|
| `image.tag` | `1.0.0-beta.8` | Pinned upstream tag |
| `rustfsConfig.accessKey` | (required) | S3 access key, min 5 chars |
| `rustfsConfig.secretKey` | (required) | S3 secret key, min 8 chars |
| `rustfsConfig.consoleEnable` | `true` | Web console enabled |
| `rustfsNetwork.apiPort` | `30100` | S3 API NodePort |
| `rustfsNetwork.consolePort` | `30101` | Console NodePort |
| `rustfsRunAs.user/group` | `10001` | Upstream container user |
| `rustfsStorage.data.hostPathConfig.hostPath` | `/mnt/Pool0/RustFS/volume1` | Default data path |
| `resources.limits.cpu` | `4000m` | CPU ceiling |
| `resources.limits.memory` | `8Gi` | Memory ceiling |

## Mode

Single-Node Single-Disk (SNSD). No erasure coding. Underlying ZFS provides redundancy.

## Additional Storage

`rustfsStorage.additionalStorages` mounts extra paths inside the container (logs, backups, etc.).
These are not RustFS data drives.

## TLS

Not surfaced in the form. To enable, set `RUSTFS_TLS_PATH` via `additionalEnvs` and mount certs via
`additionalStorages` at the matching container path.
