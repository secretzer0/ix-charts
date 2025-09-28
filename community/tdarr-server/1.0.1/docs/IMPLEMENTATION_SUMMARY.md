# Implementation Summary - Two-Instance Architecture

## Current State
- Architecture designed in `TWO_INSTANCE_ARCHITECTURE.md`
- Tdarr transcoding plugin ready: `Tdarr_Plugin_Ultimate_All_In_One.js`
- Obsolete plugin-based approach removed

## What We're Building
`external.transcoder.script.sh` - Bash script with two modes for arr coordination

### Mode 1: transcode-import
**Trigger**: Radarr/Sonarr OnDownload event (Transcode instance)
**Input**: Environment variables from arr
**Action**: Store metadata in `/var/lib/tdarr_state/movies/tt{imdb}.json`
**Output**: State file with transcode_id, imdb, tmdb, download_info

### Mode 2: tdarr-complete
**Trigger**: Tdarr post-processing after transcode
**Input**: File path in /media/
**Action**:
1. Extract IMDB+TMDB from filename
2. Read state file
3. Add to Archive instance (or find existing)
4. Trigger Archive refresh scan
5. Delete from Transcode instance (deleteFiles=true)
6. Update state file to "completed"

## Key Requirements
- Parse filenames: `{Movie} ({Year}) {imdb-tt123} {tmdb-456}.ext`
- JSON state management with atomic writes
- API calls to both arr instances
- Error handling and logging
- Support both Radarr (movies) and Sonarr (TV)