# RustFS

[RustFS](https://rustfs.com) is a high-performance, S3-compatible distributed object storage system written in Rust.

> When the application is installed, a permissions init container will be launched with **root** privileges
> to chown mounted paths to UID/GID 10001 (RustFS upstream non-root user). The main container then runs
> as a non-root user.

## Deployment Mode

This chart runs RustFS in **Single-Node Single-Disk (SNSD)** mode. One data volume is mounted to `/data`.
SNSD provides no erasure coding -- redundancy must come from the underlying storage (e.g. ZFS raidz/mirror).

For multi-drive or distributed deployments, deploy RustFS outside this chart.

## Default Storage Path

The default data path is `/mnt/Pool0/RustFS/volume1`. Create the parent dataset before deploying, or
switch the data storage type to `ixVolume` to have TrueNAS create the dataset automatically.
