# Tdarr Plugins V2 - Two-Instance Architecture

Custom Tdarr transcoding with dual Radarr/Sonarr coordination for minimal ZFS fragmentation.

---

## Overview

This repository contains the transcoding plugin and architecture design for a dual-instance Radarr/Sonarr setup that minimizes ZFS fragmentation on `/media/` dataset.

**Key Innovation**: Single write to `/media/` by coordinating two arr instances with external script.

---

## Repository Contents

### `Tdarr_Plugin_Ultimate_All_In_One.js`
**Purpose**: Core transcoding plugin (HEVC 10-bit with NVENC GPU acceleration)

**Features**:
- HEVC 10-bit encoding with NVENC GPU acceleration
- Smart audio conversion (E-AC3/AAC for Roku compatibility)
- Intelligent bitrate calculation based on resolution
- Adaptive HEVC efficiency (25-45% reduction for h264→HEVC)
- Special 10% efficiency gain for 8-bit→10-bit HEVC
- Roku-optimized MP4 output with fast streaming
- Subtitle management (mov_text for MP4, preserve for MKV)

**Status**: Production-ready, no modifications needed for new architecture

---

### `TWO_INSTANCE_ARCHITECTURE.md`
**Purpose**: Complete architecture design for dual Radarr/Sonarr coordination

**Contents**:
- Dual-instance setup (Transcode + Archive)
- State management with JSON metadata files
- API workflows for coordination
- Script modes (transcode-import, tdarr-complete)
- ZFS fragmentation analysis
- Implementation checklist

**Status**: Complete design specification, ready for implementation

---

## Architecture Summary

```
┌────────────────────────────────────────────────────────────┐
│                    WORKFLOW OVERVIEW                       │
└────────────────────────────────────────────────────────────┘

SABnzbd → /transcode/SABnzbd/complete/
    ↓
Transcode Radarr/Sonarr (7879/8990)
├─ Renames: {Movie} ({Year}) {imdb-tt123} {tmdb-456}.mkv
├─ Stores: /transcode/Movies/ or /transcode/TV/
└─ Calls: external.transcoder.script.sh transcode-import
    ↓
Tdarr Watches /transcode/
├─ Transcodes with GPU (this plugin)
└─ Outputs: /media/Movies/ or /media/TV/ ← SINGLE WRITE ✅
    ↓
Tdarr Post-Processing
└─ Calls: external.transcoder.script.sh tdarr-complete
    ↓
Archive Radarr/Sonarr (7878/8989)
├─ Adds movie via API
├─ Scans /media/ directory
└─ Tracks transcoded media
    ↓
Transcode Instance Cleanup
└─ DELETE /api/v3/movie/{id}?deleteFiles=true ✅
```

---

## Key Benefits

**1. Single Write to `/media/`** ✅
- Tdarr outputs directly to `/media/` from `/transcode/`
- No intermediate writes on Media dataset
- Minimizes ZFS fragmentation

**2. Battle-Tested File Handling** ✅
- Sonarr/Radarr handle download → rename (proven, reliable)
- IMDB+TMDB identifiers in filenames for accurate lookup
- No custom code trying to replicate arr's logic

**3. Automatic Cleanup** ✅
- Transcode instance deletes files after success
- `/transcode/` area stays clean
- No manual cleanup needed

**4. State Persistence** ✅
- Complete metadata stored in JSON files
- Download client info preserved for debugging
- Recovery possible from any failure point

---

## Plugin Usage

### Installation

1. Copy `Tdarr_Plugin_Ultimate_All_In_One.js` to Tdarr plugins directory:
   ```bash
   cp Tdarr_Plugin_Ultimate_All_In_One.js /path/to/tdarr/plugins/local/
   ```

2. Restart Tdarr server:
   ```bash
   docker-compose restart tdarr
   ```

3. Configure in Tdarr UI under Library → Transcode Options

---

### Configuration

**Plugin Stack**:
- Position 1: `Tdarr_Plugin_Ultimate_All_In_One` (this plugin)

**Library Settings**:
```yaml
Input folder: /transcode/Movies (or /transcode/TV)
Output folder: /media/Movies (or /media/TV)
Watch folders: Enable
Delete originals: After success
```

**Plugin Parameters**:
```yaml
size_tolerance: 30        # ±30% of target size
target_4k_gb: 9          # 9GB for 120min 4K movie
target_1080p_gb: 4       # 4GB for 120min 1080p movie
target_720p_gb: 2        # 2GB for 120min 720p movie
target_sd_mb: 300        # 300MB for 120min SD movie
generate_chapters: true  # Generate chapters for MP4
container: mp4           # or mkv
```

---

## External Coordination

This plugin focuses purely on transcoding. Coordination with Radarr/Sonarr is handled by:

1. **Radarr/Sonarr Custom Scripts** (transcode-import mode)
   - Triggered by: OnDownload/OnImport events
   - Purpose: Store metadata when file enters `/transcode/`
   - Location: Configured in arr Settings → Connect → Custom Script

2. **Tdarr Post-Processing** (tdarr-complete mode)
   - Triggered by: After transcoding completes
   - Purpose: Add to Archive instance, cleanup Transcode instance
   - Location: Tdarr Library Settings → Post-Processing Script

Both scripts are part of `external.transcoder.script.sh` (to be implemented).

See `TWO_INSTANCE_ARCHITECTURE.md` for complete details.

---

## File Naming Requirements

**Critical**: Transcode Radarr/Sonarr must include IMDB+TMDB identifiers in filenames.

**Radarr Naming Template**:
```
Settings → Media Management → Standard Movie Format:
{Movie Title} ({Release Year}) {imdb-{ImdbId}} {tmdb-{TmdbId}}
```

**Example Output**:
```
The Big Movie (2022) {imdb-tt1234567} {tmdb-550} Bluray-1080p.mkv
```

**Sonarr Naming Template**:
```
Settings → Media Management → Standard Episode Format:
{Series Title} - S{season:00}E{episode:00} {imdb-{ImdbId}} {tvdb-{TvdbId}}
```

**Example Output**:
```
Game of Thrones - S05E01 {imdb-tt0944947} {tvdb-121361}.mkv
```

**Why**: The external script extracts IMDB+TMDB from filenames for accurate coordination between arr instances.

---

## Troubleshooting

### Plugin Not Loading
```bash
# Check Tdarr logs
docker-compose logs tdarr | grep -i plugin

# Verify plugin syntax
node -c Tdarr_Plugin_Ultimate_All_In_One.js
```

### Transcoding Issues
```bash
# Check FFmpeg availability
docker exec tdarr-node which ffmpeg

# Check GPU access
docker exec tdarr-node nvidia-smi

# Check file permissions
ls -la /transcode/Movies/ /media/Movies/
```

### Output File Size Issues
- Adjust `size_tolerance` parameter (increase for more flexibility)
- Check `target_*_gb` settings match your quality expectations
- Review Tdarr logs for bitrate calculations

---

## Next Steps

1. **Implement `external.transcoder.script.sh`** (see TWO_INSTANCE_ARCHITECTURE.md)
2. **Deploy dual Radarr/Sonarr instances** (Transcode + Archive)
3. **Configure naming templates** with IMDB+TMDB identifiers
4. **Test end-to-end workflow** with sample files

---

## Support

For architecture questions, see `TWO_INSTANCE_ARCHITECTURE.md`.

For plugin-specific issues, check Tdarr logs and FFmpeg command output.

---

**Last Updated**: 2025-09-27
**Author**: secretzer0
**Repository**: tdarr_plugins_v2