#!/bin/bash
################################################################################
# external.transcoder.script.sh - Two-Instance Arr Coordination Script
#
# Purpose: Coordinates dual Radarr/Sonarr instances for minimal ZFS fragmentation
# Author: secretzer0
# Version: 2.0.0
#
# Modes:
#   transcode-import - Store metadata when file enters /transcode/
#   tdarr-complete   - Coordinate Archive instance + cleanup Transcode instance
#
# Usage:
#   ./external.transcoder.script.sh transcode-import
#   ./external.transcoder.script.sh tdarr-complete --file "/media/Movies/..." --type movie
################################################################################

set -euo pipefail

# Configuration
STATE_DIR="${STATE_DIR:-/var/lib/tdarr_state}"
LOG_FILE="${LOG_FILE:-/var/log/tdarr_coordination.log}"
DEBUG="${DEBUG:-false}"

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Logging Functions
################################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        ERROR)   echo -e "${RED}[ERROR]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        WARN)    echo -e "${YELLOW}[WARN]${NC} $message" ;;
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
        DEBUG)   [[ "$DEBUG" == "true" ]] && echo -e "[DEBUG] $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

################################################################################
# Utility Functions
################################################################################

extract_imdb() {
    local filename="$1"
    # Extract IMDB ID: {imdb-tt1234567}, [imdb-tt1234567], (imdb-tt1234567)
    echo "$filename" | grep -oP '[\{\[\(]imdb-(tt\d+)[\}\]\)]' | grep -oP 'tt\d+' | head -1
}

extract_tmdb() {
    local filename="$1"
    # Extract TMDB ID: {tmdb-550}, [tmdb-550], (tmdb-550)
    echo "$filename" | grep -oP '[\{\[\(]tmdb-(\d+)[\}\]\)]' | grep -oP '\d+' | head -1
}

extract_tvdb() {
    local filename="$1"
    # Extract TVDB ID: {tvdb-121361}, [tvdb-121361], (tvdb-121361)
    echo "$filename" | grep -oP '[\{\[\(]tvdb-(\d+)[\}\]\)]' | grep -oP '\d+' | head -1
}

api_call() {
    local method="$1"
    local url="$2"
    local api_key="$3"
    local data="${4:-}"

    local curl_opts=(-s -w "\n%{http_code}")

    case "$method" in
        GET)
            curl_opts+=(-X GET)
            ;;
        POST)
            curl_opts+=(-X POST -H "Content-Type: application/json" -d "$data")
            ;;
        DELETE)
            curl_opts+=(-X DELETE)
            ;;
    esac

    curl_opts+=(-H "X-Api-Key: $api_key" "$url")

    local response=$(curl "${curl_opts[@]}")
    local http_code=$(echo "$response" | tail -1)
    local body=$(echo "$response" | sed '$d')

    if [[ "$DEBUG" == "true" ]]; then
        log DEBUG "API $method $url -> HTTP $http_code"
        log DEBUG "Response: $body"
    fi

    echo "$body"
    return $([ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ] && echo 0 || echo 1)
}

atomic_write_json() {
    local filepath="$1"
    local content="$2"

    local tmp_file="${filepath}.tmp.$$"
    echo "$content" | jq '.' > "$tmp_file" || {
        log ERROR "Failed to write JSON to $tmp_file"
        rm -f "$tmp_file"
        return 1
    }

    mv "$tmp_file" "$filepath" || {
        log ERROR "Failed to move $tmp_file to $filepath"
        rm -f "$tmp_file"
        return 1
    }

    return 0
}

################################################################################
# Mode 1: transcode-import
# Triggered by: Radarr/Sonarr OnDownload event (Transcode instance)
################################################################################

mode_transcode_import() {
    log INFO "=========================================="
    log INFO "MODE: transcode-import"
    log INFO "=========================================="

    # Determine type from environment variables
    local media_type=""
    local imdb=""
    local tmdb=""
    local tvdb=""
    local internal_id=""
    local title=""
    local file_path=""
    local download_client=""
    local download_id=""

    if [[ -n "${radarr_eventtype:-}" ]]; then
        media_type="movie"
        imdb="${radarr_movie_imdbid:-}"
        tmdb="${radarr_movie_tmdbid:-}"
        internal_id="${radarr_movie_id:-}"
        title="${radarr_movie_title:-} (${radarr_movie_year:-})"
        file_path="${radarr_moviefile_path:-}"
        download_client="${radarr_download_client:-}"
        download_id="${radarr_download_id:-}"

        log INFO "Detected: Radarr movie import"
    elif [[ -n "${sonarr_eventtype:-}" ]]; then
        media_type="tv"
        imdb="${sonarr_series_imdbid:-}"
        tmdb="${sonarr_series_tmdbid:-}"
        tvdb="${sonarr_series_tvdbid:-}"
        internal_id="${sonarr_series_id:-}"
        title="${sonarr_series_title:-}"
        file_path="${sonarr_episodefile_path:-}"
        download_client="${sonarr_download_client:-}"
        download_id="${sonarr_download_id:-}"

        log INFO "Detected: Sonarr TV import"
    else
        log ERROR "No radarr_eventtype or sonarr_eventtype found in environment"
        return 1
    fi

    # Fallback: extract from filename if not in env vars
    local filename=$(basename "$file_path")
    [[ -z "$imdb" ]] && imdb=$(extract_imdb "$filename")
    [[ -z "$tmdb" ]] && tmdb=$(extract_tmdb "$filename")
    [[ -z "$tvdb" ]] && tvdb=$(extract_tvdb "$filename")

    if [[ -z "$imdb" ]]; then
        log ERROR "No IMDB ID found in environment or filename: $filename"
        return 1
    fi

    log INFO "IMDB: $imdb, TMDB: $tmdb, TVDB: $tvdb"
    log INFO "Internal ID: $internal_id"
    log INFO "Title: $title"
    log INFO "File: $file_path"

    # Create state directory
    local state_subdir="$STATE_DIR/$media_type"
    mkdir -p "$state_subdir" || {
        log ERROR "Failed to create state directory: $state_subdir"
        return 1
    }

    # Build state file content
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local state_file="$state_subdir/${imdb}.json"

    local state_content=$(jq -n \
        --arg transcode_id "$internal_id" \
        --arg transcode_url "${TRANSCODE_RADARR_URL:-${TRANSCODE_SONARR_URL:-}}" \
        --arg transcode_api_key "${TRANSCODE_RADARR_API_KEY:-${TRANSCODE_SONARR_API_KEY:-}}" \
        --arg archive_url "${ARCHIVE_RADARR_URL:-${ARCHIVE_SONARR_URL:-}}" \
        --arg archive_api_key "${ARCHIVE_RADARR_API_KEY:-${ARCHIVE_SONARR_API_KEY:-}}" \
        --arg imdb "$imdb" \
        --arg tmdb "$tmdb" \
        --arg tvdb "$tvdb" \
        --arg title "$title" \
        --arg download_client "$download_client" \
        --arg download_id "$download_id" \
        --arg file_path "$file_path" \
        --arg timestamp "$timestamp" \
        '{
            transcode_instance: {
                id: ($transcode_id | tonumber),
                url: $transcode_url,
                api_key: $transcode_api_key
            },
            archive_instance: {
                id: null,
                url: $archive_url,
                api_key: $archive_api_key
            },
            metadata: {
                imdb: $imdb,
                tmdb: $tmdb,
                tvdb: $tvdb,
                title: $title
            },
            download_info: {
                client: $download_client,
                download_id: $download_id
            },
            files: {
                transcode_path: $file_path,
                archive_path: null
            },
            state: "transcoding",
            timestamps: {
                downloaded: $timestamp,
                transcode_started: null,
                transcode_completed: null,
                archive_added: null
            }
        }')

    atomic_write_json "$state_file" "$state_content" || {
        log ERROR "Failed to write state file: $state_file"
        return 1
    }

    log SUCCESS "State file created: $state_file"
    log INFO "Ready for Tdarr transcoding"
    return 0
}

################################################################################
# Mode 2: tdarr-complete
# Triggered by: Tdarr post-processing after transcode
################################################################################

mode_tdarr_complete() {
    log INFO "=========================================="
    log INFO "MODE: tdarr-complete"
    log INFO "=========================================="

    # Parse arguments
    local file_path=""
    local media_type=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --file)
                file_path="$2"
                shift 2
                ;;
            --type)
                media_type="$2"
                shift 2
                ;;
            *)
                log ERROR "Unknown argument: $1"
                return 1
                ;;
        esac
    done

    if [[ -z "$file_path" || -z "$media_type" ]]; then
        log ERROR "Missing required arguments: --file and --type"
        return 1
    fi

    log INFO "File: $file_path"
    log INFO "Type: $media_type"

    # Extract identifiers from filename
    local filename=$(basename "$file_path")
    local imdb=$(extract_imdb "$filename")
    local tmdb=$(extract_tmdb "$filename")
    local tvdb=$(extract_tvdb "$filename")

    if [[ -z "$imdb" ]]; then
        log ERROR "No IMDB ID found in filename: $filename"
        return 1
    fi

    log INFO "Extracted - IMDB: $imdb, TMDB: $tmdb, TVDB: $tvdb"

    # Read state file
    local state_file="$STATE_DIR/$media_type/${imdb}.json"
    if [[ ! -f "$state_file" ]]; then
        log ERROR "State file not found: $state_file"
        return 1
    fi

    log INFO "Reading state file: $state_file"

    local transcode_id=$(jq -r '.transcode_instance.id' "$state_file")
    local transcode_url=$(jq -r '.transcode_instance.url' "$state_file")
    local transcode_api_key=$(jq -r '.transcode_instance.api_key' "$state_file")
    local archive_url=$(jq -r '.archive_instance.url' "$state_file")
    local archive_api_key=$(jq -r '.archive_instance.api_key' "$state_file")
    local title=$(jq -r '.metadata.title' "$state_file")

    log INFO "Transcode ID: $transcode_id"
    log INFO "Archive URL: $archive_url"

    # Step 1: Check if media exists in Archive instance
    log INFO "Step 1: Checking Archive instance for existing media..."

    local lookup_endpoint=""
    if [[ "$media_type" == "movie" ]]; then
        lookup_endpoint="$archive_url/api/v3/movie/lookup?term=imdb:$imdb"
    else
        lookup_endpoint="$archive_url/api/v3/series/lookup?term=imdb:$imdb"
    fi

    local lookup_response=$(api_call GET "$lookup_endpoint" "$archive_api_key") || {
        log WARN "Lookup failed, will attempt to add new media"
        lookup_response="[]"
    }

    local archive_id=$(echo "$lookup_response" | jq -r '.[0].id // empty')

    if [[ -z "$archive_id" ]]; then
        log INFO "Media not found in Archive, adding new entry..."

        # Add to Archive instance
        local add_endpoint=""
        local add_payload=""

        if [[ "$media_type" == "movie" ]]; then
            add_endpoint="$archive_url/api/v3/movie"
            add_payload=$(jq -n \
                --arg title "$title" \
                --arg tmdb "$tmdb" \
                '{
                    title: $title,
                    tmdbId: ($tmdb | tonumber),
                    qualityProfileId: 1,
                    rootFolderPath: "/media/Movies",
                    monitored: true,
                    addOptions: {
                        searchForMovie: false
                    }
                }')
        else
            add_endpoint="$archive_url/api/v3/series"
            add_payload=$(jq -n \
                --arg title "$title" \
                --arg tvdb "$tvdb" \
                '{
                    title: $title,
                    tvdbId: ($tvdb | tonumber),
                    qualityProfileId: 1,
                    rootFolderPath: "/media/TV",
                    monitored: true,
                    addOptions: {
                        searchForMissingEpisodes: false
                    }
                }')
        fi

        local add_response=$(api_call POST "$add_endpoint" "$archive_api_key" "$add_payload") || {
            log ERROR "Failed to add media to Archive instance"
            return 1
        }

        archive_id=$(echo "$add_response" | jq -r '.id')
        log SUCCESS "Added to Archive with ID: $archive_id"
    else
        log INFO "Media already exists in Archive with ID: $archive_id"
    fi

    # Step 2: Trigger Archive refresh scan
    log INFO "Step 2: Triggering Archive refresh scan..."

    local refresh_endpoint="$archive_url/api/v3/command"
    local refresh_payload=""

    if [[ "$media_type" == "movie" ]]; then
        refresh_payload=$(jq -n --arg id "$archive_id" '{name: "RefreshMovie", movieIds: [($id | tonumber)]}')
    else
        refresh_payload=$(jq -n --arg id "$archive_id" '{name: "RefreshSeries", seriesId: ($id | tonumber)}')
    fi

    api_call POST "$refresh_endpoint" "$archive_api_key" "$refresh_payload" || {
        log WARN "Refresh command may have failed, but continuing..."
    }

    log SUCCESS "Archive refresh triggered"

    # Step 3: Delete from Transcode instance WITH files
    log INFO "Step 3: Cleaning up Transcode instance..."

    local delete_endpoint=""
    if [[ "$media_type" == "movie" ]]; then
        delete_endpoint="$transcode_url/api/v3/movie/$transcode_id?deleteFiles=true"
    else
        delete_endpoint="$transcode_url/api/v3/series/$transcode_id?deleteFiles=true"
    fi

    api_call DELETE "$delete_endpoint" "$transcode_api_key" || {
        log WARN "Delete from Transcode may have failed"
    }

    log SUCCESS "Transcode instance cleaned (files deleted)"

    # Step 4: Update state file
    log INFO "Step 4: Updating state file..."

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local updated_state=$(jq \
        --arg archive_id "$archive_id" \
        --arg archive_path "$file_path" \
        --arg timestamp "$timestamp" \
        '.archive_instance.id = ($archive_id | tonumber) |
         .files.archive_path = $archive_path |
         .state = "completed" |
         .timestamps.transcode_completed = $timestamp |
         .timestamps.archive_added = $timestamp' \
        "$state_file")

    atomic_write_json "$state_file" "$updated_state" || {
        log WARN "Failed to update state file, but coordination succeeded"
    }

    log SUCCESS "State file updated"
    log SUCCESS "=========================================="
    log SUCCESS "Coordination complete!"
    log SUCCESS "Archive ID: $archive_id"
    log SUCCESS "File: $file_path"
    log SUCCESS "=========================================="

    return 0
}

################################################################################
# Main
################################################################################

main() {
    # Create log directory if needed
    mkdir -p "$(dirname "$LOG_FILE")"

    # Ensure required commands are available
    for cmd in jq curl; do
        if ! command -v "$cmd" &> /dev/null; then
            log ERROR "Required command not found: $cmd"
            exit 1
        fi
    done

    # Parse mode
    local mode="${1:-}"
    shift || true

    case "$mode" in
        transcode-import)
            mode_transcode_import "$@"
            ;;
        tdarr-complete)
            mode_tdarr_complete "$@"
            ;;
        *)
            echo "Usage: $0 {transcode-import|tdarr-complete} [options]"
            echo ""
            echo "Modes:"
            echo "  transcode-import     Store metadata from Radarr/Sonarr event"
            echo "  tdarr-complete       Coordinate Archive instance after Tdarr transcode"
            echo ""
            echo "Examples:"
            echo "  $0 transcode-import"
            echo "  $0 tdarr-complete --file /media/Movies/Movie.mp4 --type movie"
            exit 1
            ;;
    esac
}

main "$@"