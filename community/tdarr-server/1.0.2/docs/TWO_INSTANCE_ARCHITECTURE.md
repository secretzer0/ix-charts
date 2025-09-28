# Two-Instance Radarr/Sonarr Architecture Design

**Author**: secretzer0
**Date**: 2025-09-27
**Goal**: Minimize ZFS fragmentation using dual Radarr/Sonarr instances with Tdarr coordination

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DUAL INSTANCE WORKFLOW                           │
└─────────────────────────────────────────────────────────────────────────┘

SABnzbd Download
    │
    ├─> /transcode/SABnzbd/complete/random.release.name.mkv
    │
    v
┌──────────────────────────────────────────────────────────────────────────┐
│ TRANSCODE RADARR/SONARR          │  Port: 7879/8990                      │
│ Root: /transcode/Movies          │  Purpose: Download + Rename           │
│ Root: /transcode/TV              │  Naming: {imdb-tt123} {tmdb-456}      │
└──────────────────────────────────────────────────────────────────────────┘
    │ [OnDownload/OnImport Event]
    │ ENV: radarr_movie_id=123, radarr_movie_imdbid=tt1234567,
    │      radarr_movie_tmdbid=550, radarr_download_id=nzb_xyz
    v
┌──────────────────────────────────────────────────────────────────────────┐
│ external.transcoder.script.sh    │  Mode: transcode-import               │
│ Action: Store complete metadata │                                        │
└──────────────────────────────────────────────────────────────────────────┘
    │ Writes: /var/lib/tdarr_state/tt1234567.json
    │ {
    │   "transcode_id": 123,
    │   "archive_id": null,
    │   "imdb": "tt1234567",
    │   "tmdb": "550",
    │   "download_client": "sabnzbd",
    │   "download_id": "nzb_xyz",
    │   "file": "/transcode/Movies/Big Movie (2022) {imdb-tt1234567} {tmdb-550}.mkv",
    │   "state": "transcoding"
    │ }
    v
┌──────────────────────────────────────────────────────────────────────────┐
│ TDARR WATCHES /transcode/        │                                       │
│ Detects: Big Movie (2022) {imdb-tt1234567} {tmdb-550}.mkv                │
└──────────────────────────────────────────────────────────────────────────┘
    │ Transcodes with GPU
    v
┌──────────────────────────────────────────────────────────────────────────┐
│ TDARR OUTPUT                     │                                       │
│ /media/Movies/Big Movie (2022) {imdb-tt1234567} {tmdb-550}.mp4           │
└──────────────────────────────────────────────────────────────────────────┘
    │ [Tdarr Post-Process Plugin]
    │ Calls: external.transcoder.script.sh
    v
┌──────────────────────────────────────────────────────────────────────────┐
│ external.transcoder.script.sh    │  Mode: tdarr-complete                │
│ 1. Extract IMDB+TMDB from file   │                                       │
│ 2. Read state file               │                                       │
│ 3. Add to Archive instance       │                                       │
│ 4. Refresh Archive scan          │                                       │
│ 5. Delete from Transcode (FILES) │  ← deleteFiles=true                  │
└──────────────────────────────────────────────────────────────────────────┘
    │
    ├─> POST http://archive-radarr:7878/api/v3/movie
    │   Body: {"tmdbId": 550, "rootFolderPath": "/media/Movies", ...}
    │   Response: {"id": 456, ...}
    │
    ├─> POST http://archive-radarr:7878/api/v3/command
    │   Body: {"name": "RefreshMovie", "movieIds": [456]}
    │
    └─> DELETE http://transcode-radarr:7879/api/v3/movie/123?deleteFiles=true
        ↑ Deletes /transcode/Movies/Big Movie (2022)/ directory completely

    v
┌──────────────────────────────────────────────────────────────────────────┐
│ ARCHIVE RADARR/SONARR            │  Port: 7878/8989                      │
│ Root: /media/Movies              │  Purpose: Long-term tracking          │
│ Root: /media/TV                  │  Naming: {imdb-tt123} {tmdb-456}      │
└──────────────────────────────────────────────────────────────────────────┘
    │ Scans /media/Movies/Big Movie (2022) {imdb-tt1234567} {tmdb-550}.mp4
    │ Updates database with new file
    v
┌──────────────────────────────────────────────────────────────────────────┐
│ JELLYFIN                         │                                       │
│ Library: /media/Movies           │  Recognizes IMDB/TMDB in filename    │
│ Library: /media/TV               │                                       │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Instance Configuration

### Transcode Instance (Port 7879/8990)

**Purpose**: Download management and initial rename with IMDB+TMDB identifiers

**Radarr Settings**:
```yaml
url: http://transcode-radarr:7879
api_key: <unique_key>
root_folder: /transcode/Movies

# Media Management → File Naming
rename_movies: true
standard_movie_format: "{Movie Title} ({Release Year}) {imdb-{ImdbId}} {tmdb-{TmdbId}}"
replace_illegal_characters: true

# Completed Download Handling
completed_download_handling: true  # ENABLED - does the renaming
```

**Example Output**:
```
/transcode/Movies/The Big Movie (2022)/The Big Movie (2022) {imdb-tt1234567} {tmdb-550} Bluray-1080p.mkv
```

**Sonarr Settings**:
```yaml
url: http://transcode-sonarr:8990
api_key: <unique_key>
root_folder: /transcode/TV

# Media Management → Episode Naming
rename_episodes: true
standard_episode_format: "{Series Title} - S{season:00}E{episode:00} {imdb-{ImdbId}} {tvdb-{TvdbId}}"

# Completed Download Handling
completed_download_handling: true  # ENABLED
```

**Example Output**:
```
/transcode/TV/Game of Thrones/Season 05/Game of Thrones - S05E01 {imdb-tt0944947} {tvdb-121361}.mkv
```

**Custom Scripts (Connections)**:
```yaml
- Name: Transcode Import Metadata
  On Download: true
  Path: /opt/scripts/external.transcoder.script.sh
  Arguments: transcode-import
```

---

### Archive Instance (Port 7878/8989)

**Purpose**: Long-term tracking of transcoded media in `/media/`

**Radarr Settings**:
```yaml
url: http://archive-radarr:7878
api_key: <unique_key>
root_folder: /media/Movies

# Media Management → File Naming
rename_movies: true
standard_movie_format: "{Movie Title} ({Release Year}) {imdb-{ImdbId}} {tmdb-{TmdbId}}"
replace_illegal_characters: true

# Completed Download Handling
completed_download_handling: false  # DISABLED - manual adds only via API

# Download Clients
# NONE - this instance doesn't download anything
```

**Sonarr Settings**:
```yaml
url: http://archive-sonarr:8989
api_key: <unique_key>
root_folder: /media/TV

# Media Management → Episode Naming
rename_episodes: true
standard_episode_format: "{Series Title} - S{season:00}E{episode:00} {imdb-{ImdbId}} {tvdb-{TvdbId}}"

# Completed Download Handling
completed_download_handling: false  # DISABLED
```

---

## State Management

### State File Location
```
/var/lib/tdarr_state/
├── movies/
│   ├── tt1234567.json    # Keyed by IMDB ID
│   └── tt7654321.json
└── tv/
    ├── tt0944947.json    # Series-level metadata
    └── tt0944947_S05E01.json  # Episode-specific
```

### Enhanced State File Schema (Movies)

**File**: `/var/lib/tdarr_state/movies/tt1234567.json`

```json
{
  "transcode_instance": {
    "id": 123,
    "url": "http://transcode-radarr:7879",
    "api_key": "transcode_api_key_here"
  },
  "archive_instance": {
    "id": null,
    "url": "http://archive-radarr:7878",
    "api_key": "archive_api_key_here"
  },
  "metadata": {
    "imdb": "tt1234567",
    "tmdb": "550",
    "title": "Big Movie",
    "year": 2022
  },
  "download_info": {
    "client": "sabnzbd",
    "download_id": "SABnzbd_nzo_xyz123",
    "download_client_id": "nzb_xyz",
    "indexer": "NZBgeek",
    "release_group": "GROUP",
    "downloaded_at": "2025-09-27T10:00:00Z"
  },
  "files": {
    "transcode_path": "/transcode/Movies/Big Movie (2022)/Big Movie (2022) {imdb-tt1234567} {tmdb-550}.mkv",
    "transcode_format": "mkv",
    "transcode_quality": "Bluray-1080p",
    "transcode_size_mb": 15360,
    "archive_path": null,
    "archive_format": null,
    "archive_size_mb": null
  },
  "state": "transcoding",
  "timestamps": {
    "downloaded": "2025-09-27T10:00:00Z",
    "imported": "2025-09-27T10:02:00Z",
    "transcode_started": "2025-09-27T10:05:00Z",
    "transcode_completed": null,
    "archive_added": null,
    "transcode_deleted": null
  }
}
```

### Enhanced State File Schema (TV Shows)

**File**: `/var/lib/tdarr_state/tv/tt0944947_S05E01.json`

```json
{
  "transcode_instance": {
    "series_id": 123,
    "episode_file_id": 456,
    "url": "http://transcode-sonarr:8990",
    "api_key": "transcode_api_key_here"
  },
  "archive_instance": {
    "series_id": null,
    "episode_file_id": null,
    "url": "http://archive-sonarr:8989",
    "api_key": "archive_api_key_here"
  },
  "metadata": {
    "imdb": "tt0944947",
    "tvdb": "121361",
    "tmdb": "1399",
    "title": "Game of Thrones",
    "season": 5,
    "episode": 1
  },
  "download_info": {
    "client": "sabnzbd",
    "download_id": "SABnzbd_nzo_abc456",
    "indexer": "NZBgeek",
    "release_group": "GROUP"
  },
  "files": {
    "transcode_path": "/transcode/TV/Game of Thrones/Season 05/Game of Thrones - S05E01 {imdb-tt0944947} {tvdb-121361}.mkv",
    "archive_path": null
  },
  "state": "transcoding"
}
```

---

## Script Modes

### Mode 1: transcode-import

**Trigger**: Transcode Radarr/Sonarr OnDownload/OnImport event
**Purpose**: Store complete metadata including download client info

**Input** (Environment Variables - Radarr):
```bash
radarr_eventtype="Download"
radarr_movie_id="123"
radarr_movie_imdbid="tt1234567"
radarr_movie_tmdbid="550"
radarr_movie_title="Big Movie"
radarr_movie_year="2022"
radarr_moviefile_path="/transcode/Movies/Big Movie (2022)/Big Movie (2022) {imdb-tt1234567} {tmdb-550}.mkv"
radarr_moviefile_quality="Bluray-1080p"
radarr_moviefile_size="16106127360"
radarr_download_client="sabnzbd"
radarr_download_id="SABnzbd_nzo_xyz123"
radarr_indexer="NZBgeek"
radarr_release_group="GROUP"

# Script-specific config
TRANSCODE_RADARR_URL="http://transcode-radarr:7879"
TRANSCODE_RADARR_API_KEY="<key>"
ARCHIVE_RADARR_URL="http://archive-radarr:7878"
ARCHIVE_RADARR_API_KEY="<key>"
```

**Actions**:
1. Extract IMDB ID from `radarr_movie_imdbid` (primary) or filename (fallback)
2. Extract TMDB ID from `radarr_movie_tmdbid` (primary) or filename (fallback)
3. Create state directory if not exists: `/var/lib/tdarr_state/movies/`
4. Write state file: `/var/lib/tdarr_state/movies/tt1234567.json`
5. Include ALL metadata: transcode_id, imdb, tmdb, download_info, file paths
6. Set state to "transcoding"
7. Log operation with timestamp

**Output**: Complete state file ready for tdarr-complete phase

---

### Mode 2: tdarr-complete

**Trigger**: Tdarr post-processing plugin after successful transcode
**Purpose**: Coordinate Archive instance import and cleanup Transcode instance

**Input** (Arguments):
```bash
./external.transcoder.script.sh tdarr-complete \
  --file "/media/Movies/Big Movie (2022) {imdb-tt1234567} {tmdb-550}.mp4" \
  --type movie
```

**Actions**:

**Step 1: Extract Identifiers**
```bash
# Parse filename for IMDB and TMDB
filename="Big Movie (2022) {imdb-tt1234567} {tmdb-550}.mp4"
imdb=$(echo "$filename" | grep -oP '\{imdb-(tt\d+)\}' | grep -oP 'tt\d+')
tmdb=$(echo "$filename" | grep -oP '\{tmdb-(\d+)\}' | grep -oP '\d+')

# Result: imdb="tt1234567", tmdb="550"
```

**Step 2: Read State File**
```bash
state_file="/var/lib/tdarr_state/movies/${imdb}.json"
if [[ ! -f "$state_file" ]]; then
  echo "ERROR: State file not found for IMDB ${imdb}"
  exit 1
fi

transcode_id=$(jq -r '.transcode_instance.id' "$state_file")
transcode_url=$(jq -r '.transcode_instance.url' "$state_file")
transcode_api_key=$(jq -r '.transcode_instance.api_key' "$state_file")

archive_url=$(jq -r '.archive_instance.url' "$state_file")
archive_api_key=$(jq -r '.archive_instance.api_key' "$state_file")
```

**Step 3: Add to Archive Instance**
```bash
# Check if movie already exists in Archive
lookup_response=$(curl -s "${archive_url}/api/v3/movie/lookup?term=imdb:${imdb}" \
  -H "X-Api-Key: ${archive_api_key}")

archive_id=$(echo "$lookup_response" | jq -r '.[0].id // empty')

if [[ -z "$archive_id" ]]; then
  # Movie doesn't exist, add it
  add_response=$(curl -s -X POST "${archive_url}/api/v3/movie" \
    -H "X-Api-Key: ${archive_api_key}" \
    -H "Content-Type: application/json" \
    -d "{
      \"title\": \"Big Movie\",
      \"year\": 2022,
      \"tmdbId\": ${tmdb},
      \"qualityProfileId\": 1,
      \"rootFolderPath\": \"/media/Movies\",
      \"monitored\": true,
      \"addOptions\": {
        \"searchForMovie\": false
      }
    }")

  archive_id=$(echo "$add_response" | jq -r '.id')
  echo "Added movie to Archive instance with ID: ${archive_id}"
else
  echo "Movie already exists in Archive instance with ID: ${archive_id}"
fi
```

**Step 4: Refresh Archive Scan**
```bash
# Tell Archive instance to scan /media/ directory for this movie
curl -s -X POST "${archive_url}/api/v3/command" \
  -H "X-Api-Key: ${archive_api_key}" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"RefreshMovie\",
    \"movieIds\": [${archive_id}]
  }"

echo "Triggered Archive refresh for movie ID: ${archive_id}"
```

**Step 5: Delete from Transcode (WITH FILES)**
```bash
# Delete movie from Transcode instance AND remove files from /transcode/
curl -s -X DELETE "${transcode_url}/api/v3/movie/${transcode_id}?deleteFiles=true" \
  -H "X-Api-Key: ${transcode_api_key}"

echo "Deleted movie ID ${transcode_id} from Transcode instance (files removed)"
```

**Step 6: Update State File**
```bash
# Update state file with completion info
jq --arg archive_id "$archive_id" \
   --arg archive_path "/media/Movies/Big Movie (2022) {imdb-tt1234567} {tmdb-550}.mp4" \
   --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.archive_instance.id = ($archive_id | tonumber) |
    .files.archive_path = $archive_path |
    .state = "completed" |
    .timestamps.transcode_completed = $timestamp |
    .timestamps.archive_added = $timestamp |
    .timestamps.transcode_deleted = $timestamp' \
   "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

echo "State file updated with completion status"
```

**Output**:
- Archive instance has movie and knows about transcoded file
- Transcode instance cleaned up (database entry + files removed)
- State file updated with "completed" status

---

## API Reference

### Radarr: Lookup Movie by IMDB

**Endpoint**: `GET /api/v3/movie/lookup?term=imdb:tt1234567`

**Response**:
```json
[
  {
    "id": 456,
    "title": "Big Movie",
    "year": 2022,
    "imdbId": "tt1234567",
    "tmdbId": 550,
    "path": "/media/Movies/Big Movie (2022)",
    ...
  }
]
```

**Use Case**: Check if movie already exists in Archive instance before adding

---

### Radarr: Add Movie

**Endpoint**: `POST /api/v3/movie`

**Request**:
```json
{
  "title": "Big Movie",
  "year": 2022,
  "tmdbId": 550,
  "qualityProfileId": 1,
  "rootFolderPath": "/media/Movies",
  "monitored": true,
  "addOptions": {
    "searchForMovie": false
  }
}
```

**Response**:
```json
{
  "id": 456,
  "title": "Big Movie",
  "year": 2022,
  "path": "/media/Movies/Big Movie (2022)",
  ...
}
```

---

### Radarr: Refresh Movie

**Endpoint**: `POST /api/v3/command`

**Request**:
```json
{
  "name": "RefreshMovie",
  "movieIds": [456]
}
```

**What This Does**:
- Scans `/media/Movies/Big Movie (2022)/` directory
- Finds transcoded file with matching IMDB+TMDB identifiers
- Updates database with new file metadata (size, codec, quality)

---

### Radarr: Delete Movie WITH Files

**Endpoint**: `DELETE /api/v3/movie/123?deleteFiles=true`

**Parameters**:
- `deleteFiles=true` - Delete movie directory and all files
- `addImportExclusion=false` - Don't blacklist (default)

**What This Does**:
- Removes movie ID 123 from database
- Deletes `/transcode/Movies/Big Movie (2022)/` directory completely
- Keeps `/transcode/` area clean and prevents disk filling

---

### Sonarr: Similar APIs

**Lookup Series**: `GET /api/v3/series/lookup?term=imdb:tt0944947`

**Add Series**: `POST /api/v3/series`

**Refresh Series**: `POST /api/v3/command {"name": "RefreshSeries", "seriesId": 789}`

**Delete Series**: `DELETE /api/v3/series/123?deleteFiles=true`

---

## ZFS Fragmentation Analysis

### Single Write to /media/

**Workflow**:
```
SABnzbd writes to: /transcode/SABnzbd/complete/  (Transcode dataset)
  ↓
Transcode Radarr renames to: /transcode/Movies/  (Transcode dataset)
  ↓
Tdarr transcodes: working in /transcode/cache/  (Transcode dataset)
  ↓
Tdarr outputs to: /media/Movies/                (Media dataset) ← SINGLE WRITE
  ↓
Archive Radarr scans: /media/Movies/             (Read-only operation)
  ↓
Transcode cleanup: DELETE /transcode/Movies/     (Transcode dataset)
```

**Result**: Only ONE write to `/media/` ZFS dataset ✅

**Cleanup**: `/transcode/` area automatically cleaned via `deleteFiles=true` ✅

---

## Filename Parsing Patterns

### Extract IMDB from Filename

```bash
# Bash regex
imdb=$(echo "$filename" | grep -oP '\{imdb-(tt\d+)\}' | grep -oP 'tt\d+')

# Python regex
import re
match = re.search(r'\{imdb-(tt\d+)\}', filename)
imdb = match.group(1) if match else None
```

**Supported Formats**:
- `{imdb-tt1234567}` ✅ (recommended)
- `[imdb-tt1234567]` ✅ (fallback)
- `(imdb-tt1234567)` ✅ (fallback)

### Extract TMDB from Filename

```bash
# Bash regex
tmdb=$(echo "$filename" | grep -oP '\{tmdb-(\d+)\}' | grep -oP '\d+')

# Python regex
import re
match = re.search(r'\{tmdb-(\d+)\}', filename)
tmdb = match.group(1) if match else None
```

**Supported Formats**:
- `{tmdb-550}` ✅ (recommended)
- `[tmdb-550]` ✅ (fallback)
- `(tmdb-550)` ✅ (fallback)

---

## Implementation Checklist

### Infrastructure Setup
- [ ] Deploy Transcode Radarr (port 7879) with IMDB+TMDB naming
- [ ] Deploy Archive Radarr (port 7878) with IMDB+TMDB naming
- [ ] Deploy Transcode Sonarr (port 8990) with IMDB+TVDB naming
- [ ] Deploy Archive Sonarr (port 8989) with IMDB+TVDB naming
- [ ] Configure SABnzbd with transcode instances only
- [ ] Create `/var/lib/tdarr_state/{movies,tv}/` with proper permissions
- [ ] Set up custom script connections in Transcode instances

### Script Development
- [ ] Create `external.transcoder.script.sh` with two modes
- [ ] Implement transcode-import mode (complete metadata storage)
- [ ] Implement tdarr-complete mode with IMDB+TMDB parsing
- [ ] Add Archive lookup/add/refresh logic
- [ ] Add Transcode delete with `deleteFiles=true`
- [ ] Add state file update logic
- [ ] Add comprehensive error handling and logging

### Tdarr Configuration
- [ ] Configure Tdarr to watch `/transcode/Movies` and `/transcode/TV`
- [ ] Configure Tdarr output to `/media/Movies` and `/media/TV`
- [ ] Preserve IMDB+TMDB identifiers in output filename
- [ ] Create post-processing plugin that calls script in tdarr-complete mode

### Testing
- [ ] Test movie: SABnzbd → Transcode Radarr → Tdarr → Archive Radarr
- [ ] Test TV: SABnzbd → Transcode Sonarr → Tdarr → Archive Sonarr
- [ ] Verify state files created correctly
- [ ] Verify `/transcode/` cleanup (files deleted)
- [ ] Verify `/media/` single write (no fragmentation)
- [ ] Test failure recovery scenarios

---

**End of Architecture Design**