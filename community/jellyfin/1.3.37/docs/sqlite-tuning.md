# Jellyfin 12.0 SQLite Tuning

## Purpose

This document records the SQLite tuning applied to the production Jellyfin
instance (custom `secretzer0/jellyfin:master-12.0.0-*` fork running on
TrueNAS SCALE Dragonfish 24.04 in the `ix-jellyfin` namespace) and explains
why each knob was set. The chart itself does not install or template this
file. The tuning lives in the config ixVolume at:

```
/mnt/Pool0/ix-applications/releases/jellyfin/volumes/ix_volumes/config/config/database.xml
```

A sample copy of the in-production file is preserved alongside this doc as
`database.xml.sample` so the tuning can be re-applied after any future
chart uninstall and reinstall.

## Why this was done

The Jellyfin 12.0 fork moved SQLite configuration off environment variables
(the legacy `sqlite:cacheSize` key feeds the now-dead `SqliteItemRepository`
path) and onto a managed XML configuration store. The active code path is
`AddPooledDbContextFactory<JellyfinDbContext>` registered in
`Jellyfin.Server.Implementations/Extensions/ServiceCollectionExtensions.cs`,
which reads `DatabaseConfigurationOptions` from
`<config-root>/config/database.xml`.

By default that file contains only the database type and locking behavior,
so SQLite ran with:

- Per-connection page cache of 2 MiB (`PRAGMA cache_size=-2000`)
- No `busy_timeout` (immediate `SQLITE_BUSY` under contention)
- No `mmap_size`
- WAL autocheckpoint every ~4 MiB (~1000 pages)
- 60s EFCore command timeout

Against the live database (`jellyfin.db` = 819 MiB, 93,870 `BaseItems`,
six users, steady ingest from arr stack, multiple concurrent clients) the
default page cache caused continuous disk re-reads on metadata queries,
and the missing `busy_timeout` produced lock-contention errors under
simultaneous read/write load.

After applying the tuning in `database.xml.sample`, in-pod probes show
`/health`, `/System/Info/Public`, and `/Items/Counts` returning in 2 to
7 ms with the same dataset, and the SQLITE_BUSY noise in the log
disappeared.

## What each setting does

All values live inside `<CustomProviderOptions><Options>` as
`<CustomDatabaseOption><Key>...</Key><Value>...</Value></CustomDatabaseOption>`
entries. Keys without the `#PRAGMA:` prefix are consumed by the provider's
own option parser (`SqliteDatabaseProvider.cs:63-91`). Keys with
`#PRAGMA:` are passed through to the connection PRAGMA interceptor
(`PragmaConnectionInterceptor.cs`) and executed on every connection open.

| Key | Value | Effect | Rationale |
|---|---|---|---|
| `pooling` | `true` | Microsoft.Data.Sqlite connection pool on | Required for EFCore pooled DbContext factory to perform; do not disable |
| `command-timeout` | `120` | EFCore command timeout in seconds | Large library scans and bulk metadata updates can exceed the 60s default during chapter image extraction and trickplay generation |
| `cacheSize` | `-262144` | 256 MiB per-connection page cache (negative value = KiB) | At 819 MiB DB the default 2 MiB cache evicted hot pages constantly. 256 MiB keeps the entire BaseItems index and most provider tables hot |
| `journalsizelimit` | `268435456` | Cap WAL at 256 MiB | Allows large transactions during library scans to coalesce before checkpoint, but stops the WAL from growing without bound |
| `tempstoremode` | `2` | `PRAGMA temp_store=MEMORY` | Sort and group buffers live in RAM, not on disk; matches Jellyfin default but made explicit |
| `syncmode` | `1` | `PRAGMA synchronous=NORMAL` | Safe with WAL; FULL (2) only matters for non-WAL journal modes |
| `lockingmode` | `NORMAL` | `PRAGMA locking_mode=NORMAL` | EXCLUSIVE would prevent any other process (sqlite3 CLI, backup, debugger) from attaching; NORMAL is required for our operational workflow |
| `#PRAGMA:journal_mode` | `WAL` | Write-ahead log journaling | Required for concurrent readers during scanner writes; persistent in DB file header |
| `#PRAGMA:wal_autocheckpoint` | `10000` | Checkpoint WAL every ~40 MiB (10k pages at 4 KiB) | Default 1000 pages thrashed disk during ingest; 10k pages still bounded by `journalsizelimit` |
| `#PRAGMA:busy_timeout` | `15000` | Wait 15 seconds on a busy lock before erroring | Default 0 produces immediate `SQLITE_BUSY` errors when scanner write and client read collide. 15s lets contention resolve naturally |
| `#PRAGMA:mmap_size` | `268435456` | Memory-map up to 256 MiB of the DB file for reads | Reduces syscall overhead on hot reads; safe on Linux with ZFS as the underlying filesystem |
| `#PRAGMA:foreign_keys` | `ON` | Enforce FK constraints | Already on for the EFCore-managed schema but made explicit for direct-sqlite tooling |

## Operational notes

- The connection string itself is rebuilt by the provider on every pod
  start using `path`, `cache`, `pooling`, and `command-timeout` from the
  options block. PRAGMAs run once per connection open via the
  `PragmaConnectionInterceptor`.
- `PRAGMA cache_size` is **per connection**. Total cache memory is
  approximately `pool_size * 256 MiB`. The pod's container memory limit
  must remain at or above 8 GiB to absorb this comfortably. If the pool
  fills aggressively under load and the container approaches its limit,
  drop `cacheSize` to `-131072` (128 MiB) first before raising the
  container limit.
- `journal_mode=WAL` is persistent in the database file header. The
  PRAGMA in the connection interceptor is technically redundant after
  the first open but is kept in the file as documentation of intent.
- After editing `database.xml`, restart the pod. Verify the new
  pragma block in the log:

  ```bash
  ssh 192.168.84.100 'sudo k3s kubectl -n ix-jellyfin rollout restart deploy/jellyfin \
    && sleep 20 \
    && sudo k3s kubectl -n ix-jellyfin logs deploy/jellyfin | grep -A12 "pragma command"'
  ```

- Backups of the previous file should be kept beside the active file as
  `database.xml.bak.<unix-ts>`. A backup of the pre-tuning default is at
  `/mnt/Pool0/ix-applications/releases/jellyfin/volumes/ix_volumes/config/config/database.xml.bak.1781644707`
  on the production box.

## Persistence and reinstall behavior

- Persists across: pod restarts, deployment rollouts, helm upgrades, chart
  version bumps. The file lives on the `config` ixVolume which rebinds
  cleanly across all of these.
- Lost on: full chart uninstall (the ixVolume is destroyed). On reinstall,
  Jellyfin writes the default minimal `database.xml` on first boot. Re-apply
  the tuning from `database.xml.sample` before placing real load on the
  instance.
- The chart does not currently template or install this file. If the user
  base for this fork grows or the reinstall workflow becomes a frequent
  burden, consider adding an `install`-type init container that copies
  `database.xml.sample` into place only when the destination file lacks
  the `CustomProviderOptions` block. The shape was sketched in the
  associated session log; do not write it unconditionally on every start
  or it will stomp later UI-driven changes.

## Verification commands

Confirm what the live server actually applied (per-connection PRAGMAs are
only visible inside Jellyfin's own connections; external `sqlite3` sessions
will show their own defaults, not Jellyfin's):

```bash
ssh 192.168.84.100 'sudo k3s kubectl -n ix-jellyfin logs deploy/jellyfin \
  | grep -A12 "SQLITE connection pragma\|SQLite connection string" | head -30'
```

Confirm the database-wide journal mode (persistent in file header,
externally readable):

```bash
ssh 192.168.84.100 'sudo sqlite3 \
  /mnt/Pool0/ix-applications/releases/jellyfin/volumes/ix_volumes/config/data/jellyfin.db \
  "PRAGMA journal_mode; PRAGMA page_size;"'
```

Backend response time sanity check:

```bash
ssh 192.168.84.100 'sudo k3s kubectl -n ix-jellyfin exec deploy/jellyfin -- \
  curl -s -m 5 -o /dev/null -w "code=%{http_code} t=%{time_total}\n" \
  http://127.0.0.1:8096/health'
```

Expected: `code=200 t=0.00x` (single-digit milliseconds).

## What to watch as the library grows

These thresholds are not hard limits, only signals that the next tuning
pass is due. Re-evaluate when any of them fires.

### Database file size

- **At ~1.5 GiB:** raise `cacheSize` to `-393216` (384 MiB) if the
  container memory limit is at 12 GiB or higher. Below 12 GiB, leave
  cacheSize alone and raise the container limit first.
- **At ~3 GiB or above:** the SQLite single-file architecture starts
  to feel its age on metadata-heavy queries. Watch query latency in
  `/Items` API logs. If p99 climbs above 500 ms, evaluate the PostgreSQL
  provider plugin path (`Jellyfin.Database.Providers.PgSql` follows the
  same `IJellyfinDatabaseProvider` interface used by
  `SqliteDatabaseProvider`; see `ServiceCollectionExtensions.cs` for
  the plugin loading flow). PostgreSQL on a separate container with
  its own resources removes the per-connection cache amplification
  entirely.

### BaseItems row count

- **At ~150,000 items:** bump `wal_autocheckpoint` to `20000` (about
  80 MiB between checkpoints) if disk I/O during scans is causing
  pauses in playback. Keep `journalsizelimit` at least 4 times the
  checkpoint interval (so `>= 320 MiB`).
- **At ~250,000 items:** the index pages for `BaseItems` and
  `PeopleBaseItemMap` will dominate the cache. Verify with
  `sudo sqlite3 jellyfin.db "ANALYZE; SELECT name, stat FROM sqlite_stat1"`.
  If the largest index sets exceed half the configured cache,
  the cache is no longer hot. Either raise `cacheSize` or move to
  PostgreSQL.

### Concurrency

- **More than 8 simultaneous active sessions:** check the log for
  `database is locked` or `SQLITE_BUSY`. If they reappear despite the
  15s `busy_timeout`, raise to `30000` and verify that
  `LockingBehavior=NoLock` is still the configured app-level behavior.
  Do not switch to `Pessimistic` unless you can prove app-level write
  serialization is the cause; it has worse aggregate throughput.
- **Heavy concurrent ingest from multiple arr applications:** raise
  `command-timeout` to `240`. The default scanner does long-running
  transactions on metadata updates and image extraction.

### Container memory pressure

- **Pod memory utilization sustained above 75% of limit:** the
  per-connection 256 MiB cache is the largest tunable cost. Halve
  `cacheSize` to `-131072` before reducing pool size; reducing the
  pool hurts concurrency more than reducing per-connection cache.
- **OOM kill observed:** check `sudo k3s kubectl describe pod` for
  `OOMKilled` reason on the previous container. Reduce `cacheSize`
  and `mmap_size` together; do not leave them mismatched (SQLite
  uses both as caches and they overlap).

### Filesystem-level signals

- **WAL file (`jellyfin.db-wal`) consistently larger than 200 MiB
  during steady state:** auto-checkpoint is falling behind ingest.
  Drop `wal_autocheckpoint` to `5000` (more frequent checkpoints,
  more I/O, smaller WAL).
- **WAL file approaches `journalsizelimit`:** the limit is doing its
  job; verify checkpoints are succeeding by grepping the log for
  `wal_checkpoint`. The scheduled optimization task
  (`RunScheduledOptimisation` in `SqliteDatabaseProvider.cs`) runs
  `PRAGMA wal_checkpoint(TRUNCATE)` and `VACUUM` on the Jellyfin
  scheduled task schedule. Confirm it is enabled in the admin UI under
  Dashboard -> Scheduled Tasks -> Optimize database.

## Reference points in the Jellyfin source

For future debugging or when a 12.x point release changes behavior, the
load-bearing files in the fork (`/home/tmelhiser/jellyfin`) are:

- `src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/SqliteDatabaseProvider.cs`
  - Connection string builder, option parsing, scheduled optimization,
    backup/restore, purge.
- `src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/PragmaConnectionInterceptor.cs`
  - Per-connection PRAGMA injection. Adds new PRAGMAs to the
    `BuildCommandText` output when new keys are added to
    `CustomProviderOptions.Options` with the `#PRAGMA:` prefix.
- `src/Jellyfin.Database/Jellyfin.Database.Implementations/DbConfiguration/DatabaseConfigurationOptions.cs`
  - Top-level shape of `database.xml`. New top-level fields here would
    require a chart-side migration.
- `Jellyfin.Server.Implementations/Extensions/ServiceCollectionExtensions.cs`
  - Where `AddPooledDbContextFactory<JellyfinDbContext>` is registered
    and where the DB provider is selected from the configured type.
- `Jellyfin.Server.Implementations/DbConfiguration/DatabaseConfigurationStore.cs`
  - Maps `database.xml` to `DatabaseConfigurationOptions` via the
    Jellyfin XML serializer.

When pulling the latest 12.0 main branch into the fork, diff these files
against the previous tag. If `SqliteDatabaseProvider.cs` adds a new option
key or `PragmaConnectionInterceptor.cs` changes the default for any
PRAGMA listed above, update `database.xml.sample` and this document in
the same commit as the chart bump.
