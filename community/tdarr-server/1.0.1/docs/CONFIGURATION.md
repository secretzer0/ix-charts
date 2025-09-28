# Configuration Guide - Two-Instance Architecture

Complete setup guide for dual Radarr/Sonarr coordination with `external.transcoder.script.sh`.

---

## Prerequisites

Install required packages:
```bash
sudo apt-get update
sudo apt-get install -y jq curl
```

---

## Script Installation

```bash
# Copy script to shared location
sudo cp external.transcoder.script.sh /opt/scripts/
sudo chmod +x /opt/scripts/external.transcoder.script.sh

# Create state directory
sudo mkdir -p /var/lib/tdarr_state/{movies,tv}
sudo chown -R media:media /var/lib/tdarr_state  # Adjust user:group as needed

# Create log directory
sudo mkdir -p /var/log
sudo touch /var/log/tdarr_coordination.log
sudo chown media:media /var/log/tdarr_coordination.log
```

---

## Environment Variables

Create environment file for arr instances:

**File**: `/etc/tdarr/arr_config.env`

```bash
# Transcode Instance URLs
TRANSCODE_RADARR_URL="http://transcode-radarr:7879"
TRANSCODE_SONARR_URL="http://transcode-sonarr:8990"

# Transcode Instance API Keys
TRANSCODE_RADARR_API_KEY="your_transcode_radarr_api_key_here"
TRANSCODE_SONARR_API_KEY="your_transcode_sonarr_api_key_here"

# Archive Instance URLs
ARCHIVE_RADARR_URL="http://archive-radarr:7878"
ARCHIVE_SONARR_URL="http://archive-sonarr:8989"

# Archive Instance API Keys
ARCHIVE_RADARR_API_KEY="your_archive_radarr_api_key_here"
ARCHIVE_SONARR_API_KEY="your_archive_sonarr_api_key_here"

# Optional: State and log directories
STATE_DIR="/var/lib/tdarr_state"
LOG_FILE="/var/log/tdarr_coordination.log"
DEBUG="false"  # Set to "true" for verbose logging
```

**Set permissions**:
```bash
sudo chmod 600 /etc/tdarr/arr_config.env
sudo chown media:media /etc/tdarr/arr_config.env
```

---

## Radarr Configuration (Both Instances)

### Transcode Radarr (Port 7879)

**1. Media Management → File Naming**

```
Settings → Media Management → Movie Naming

☑ Rename Movies: Enabled

Standard Movie Format:
{Movie Title} ({Release Year}) {imdb-{ImdbId}} {tmdb-{TmdbId}}

Example output:
The Big Movie (2022) {imdb-tt1234567} {tmdb-550} Bluray-1080p.mkv
```

**2. Download Client**

```
Settings → Download Clients → Add SABnzbd

Name: SABnzbd
Host: localhost
Port: 8080
Category: movies
```

**3. Root Folder**

```
Settings → Media Management → Root Folders

Add: /transcode/Movies
```

**4. Custom Script Connection**

```
Settings → Connect → Add Custom Script

Name: Transcode Import Metadata
Notification Triggers:
  ☑ On Download
  ☑ On Import
  ☐ On Upgrade
  ☐ On Rename
  ☐ On Movie Added
  ☐ On Movie Delete
  ☐ On Health Issue

Path: /opt/scripts/external.transcoder.script.sh
Arguments: transcode-import
```

**5. Environment Variables for Custom Script**

Add to Radarr container environment or systemd service:

```yaml
# docker-compose.yml
services:
  transcode-radarr:
    environment:
      - TRANSCODE_RADARR_URL=http://transcode-radarr:7879
      - TRANSCODE_RADARR_API_KEY=your_key_here
      - ARCHIVE_RADARR_URL=http://archive-radarr:7878
      - ARCHIVE_RADARR_API_KEY=your_key_here
    env_file:
      - /etc/tdarr/arr_config.env
```

---

### Archive Radarr (Port 7878)

**1. Media Management → File Naming**

```
Settings → Media Management → Movie Naming

☑ Rename Movies: Enabled

Standard Movie Format:
{Movie Title} ({Release Year}) {imdb-{ImdbId}} {tmdb-{TmdbId}}
```

**2. Download Client**

```
Settings → Download Clients

No download clients configured - this instance doesn't download
```

**3. Root Folder**

```
Settings → Media Management → Root Folders

Add: /media/Movies
```

**4. Completed Download Handling**

```
Settings → Media Management

☐ Completed Download Handling: DISABLED
```

---

## Sonarr Configuration (Both Instances)

### Transcode Sonarr (Port 8990)

**1. Media Management → Episode Naming**

```
Settings → Media Management → Episode Naming

☑ Rename Episodes: Enabled

Standard Episode Format:
{Series Title} - S{season:00}E{episode:00} {imdb-{ImdbId}} {tvdb-{TvdbId}}

Example output:
Game of Thrones - S05E01 {imdb-tt0944947} {tvdb-121361}.mkv
```

**2. Download Client**

```
Settings → Download Clients → Add SABnzbd

Name: SABnzbd
Host: localhost
Port: 8080
Category: tv
```

**3. Root Folder**

```
Settings → Media Management → Root Folders

Add: /transcode/TV
```

**4. Custom Script Connection**

```
Settings → Connect → Add Custom Script

Name: Transcode Import Metadata
Notification Triggers:
  ☑ On Download
  ☑ On Import
  ☑ On Episode File Import
  ☐ On Upgrade
  ☐ On Rename
  ☐ On Series Add
  ☐ On Series Delete
  ☐ On Health Issue

Path: /opt/scripts/external.transcoder.script.sh
Arguments: transcode-import
```

**5. Environment Variables for Custom Script**

```yaml
# docker-compose.yml
services:
  transcode-sonarr:
    environment:
      - TRANSCODE_SONARR_URL=http://transcode-sonarr:8990
      - TRANSCODE_SONARR_API_KEY=your_key_here
      - ARCHIVE_SONARR_URL=http://archive-sonarr:8989
      - ARCHIVE_SONARR_API_KEY=your_key_here
    env_file:
      - /etc/tdarr/arr_config.env
```

---

### Archive Sonarr (Port 8989)

**1. Media Management → Episode Naming**

```
Settings → Media Management → Episode Naming

☑ Rename Episodes: Enabled

Standard Episode Format:
{Series Title} - S{season:00}E{episode:00} {imdb-{ImdbId}} {tvdb-{TvdbId}}
```

**2. Download Client**

```
Settings → Download Clients

No download clients configured - this instance doesn't download
```

**3. Root Folder**

```
Settings → Media Management → Root Folders

Add: /media/TV
```

**4. Completed Download Handling**

```
Settings → Media Management

☐ Completed Download Handling: DISABLED
```

---

## Tdarr Configuration

### Library Setup

**Movies Library**:
```
Name: Movies
Source: /transcode/Movies
Transcode cache: /transcode/cache
Output: /media/Movies

☑ Watch folder for new files
☑ Delete source files after successful transcode
```

**TV Library**:
```
Name: TV
Source: /transcode/TV
Transcode cache: /transcode/cache
Output: /media/TV

☑ Watch folder for new files
☑ Delete source files after successful transcode
```

### Post-Processing Script

**Method 1: Tdarr Flows (Recommended)**

Create a Flow plugin with final node:

```
Node Type: Execute
Command: /opt/scripts/external.transcoder.script.sh
Arguments: tdarr-complete --file "{{file}}" --type {{library_type}}
```

**Method 2: Library Post-Processing Hook**

If Tdarr supports post-processing hooks:

```
Settings → Libraries → Movies → Post-Processing

Script: /opt/scripts/external.transcoder.script.sh
Arguments: tdarr-complete --file "{file}" --type movie
```

**Method 3: Wrapper Script** (fallback)

Create wrapper that Tdarr calls:

```bash
#!/bin/bash
# /opt/scripts/tdarr_post_process.sh

FILE="$1"
LIBRARY_TYPE="$2"  # "movie" or "tv"

source /etc/tdarr/arr_config.env
/opt/scripts/external.transcoder.script.sh tdarr-complete \
    --file "$FILE" \
    --type "$LIBRARY_TYPE"
```

---

## Testing

### Test transcode-import Mode

```bash
# Set environment variables manually
export radarr_eventtype="Download"
export radarr_movie_id="123"
export radarr_movie_imdbid="tt1234567"
export radarr_movie_tmdbid="550"
export radarr_movie_title="Test Movie"
export radarr_movie_year="2022"
export radarr_moviefile_path="/transcode/Movies/Test Movie (2022) {imdb-tt1234567} {tmdb-550}.mkv"
export radarr_download_client="sabnzbd"
export radarr_download_id="SABnzbd_nzo_test123"

export TRANSCODE_RADARR_URL="http://transcode-radarr:7879"
export TRANSCODE_RADARR_API_KEY="your_key_here"
export ARCHIVE_RADARR_URL="http://archive-radarr:7878"
export ARCHIVE_RADARR_API_KEY="your_key_here"

# Run script
/opt/scripts/external.transcoder.script.sh transcode-import

# Check state file created
cat /var/lib/tdarr_state/movie/tt1234567.json
```

### Test tdarr-complete Mode

```bash
# Source environment
source /etc/tdarr/arr_config.env

# Create test transcoded file
touch "/media/Movies/Test Movie (2022) {imdb-tt1234567} {tmdb-550}.mp4"

# Run script
/opt/scripts/external.transcoder.script.sh tdarr-complete \
    --file "/media/Movies/Test Movie (2022) {imdb-tt1234567} {tmdb-550}.mp4" \
    --type movie

# Check logs
tail -f /var/log/tdarr_coordination.log
```

---

## Troubleshooting

### Check Script Logs

```bash
tail -f /var/log/tdarr_coordination.log
```

### Enable Debug Mode

```bash
export DEBUG="true"
/opt/scripts/external.transcoder.script.sh tdarr-complete --file "..." --type movie
```

### Verify State Files

```bash
# List all state files
find /var/lib/tdarr_state -name "*.json" -exec basename {} \;

# View specific state file
cat /var/lib/tdarr_state/movie/tt1234567.json | jq '.'
```

### Test API Connectivity

```bash
# Test Transcode Radarr
curl -s "http://transcode-radarr:7879/api/v3/system/status" \
    -H "X-Api-Key: your_key_here" | jq '.'

# Test Archive Radarr
curl -s "http://archive-radarr:7878/api/v3/system/status" \
    -H "X-Api-Key: your_key_here" | jq '.'
```

### Common Issues

**"State file not found"**
- Verify transcode-import ran successfully
- Check `/var/lib/tdarr_state/` permissions
- Verify IMDB ID matches between modes

**"API call failed"**
- Check arr instance URLs and API keys
- Verify network connectivity between containers
- Check arr logs for errors

**"No IMDB ID found in filename"**
- Verify arr naming templates include `{imdb-{ImdbId}}`
- Check transcode instance actually renamed file
- Verify file exists at expected path

---

## Docker Compose Example

Complete setup with all components:

```yaml
version: "3.8"

services:
  # Transcode Instances
  transcode-radarr:
    image: linuxserver/radarr:latest
    container_name: transcode-radarr
    ports:
      - "7879:7878"
    volumes:
      - /path/to/config/transcode-radarr:/config
      - /transcode:/transcode
      - /opt/scripts:/scripts:ro
    env_file:
      - /etc/tdarr/arr_config.env
    restart: unless-stopped

  transcode-sonarr:
    image: linuxserver/sonarr:latest
    container_name: transcode-sonarr
    ports:
      - "8990:8989"
    volumes:
      - /path/to/config/transcode-sonarr:/config
      - /transcode:/transcode
      - /opt/scripts:/scripts:ro
    env_file:
      - /etc/tdarr/arr_config.env
    restart: unless-stopped

  # Archive Instances
  archive-radarr:
    image: linuxserver/radarr:latest
    container_name: archive-radarr
    ports:
      - "7878:7878"
    volumes:
      - /path/to/config/archive-radarr:/config
      - /media:/media
    env_file:
      - /etc/tdarr/arr_config.env
    restart: unless-stopped

  archive-sonarr:
    image: linuxserver/sonarr:latest
    container_name: archive-sonarr
    ports:
      - "8989:8989"
    volumes:
      - /path/to/config/archive-sonarr:/config
      - /media:/media
    env_file:
      - /etc/tdarr/arr_config.env
    restart: unless-stopped

  # Tdarr
  tdarr:
    image: ghcr.io/haveagitgat/tdarr:latest
    container_name: tdarr
    ports:
      - "8265:8265"
      - "8266:8266"
    volumes:
      - /path/to/config/tdarr:/app/server
      - /transcode:/transcode
      - /media:/media
      - /opt/scripts:/scripts:ro
    env_file:
      - /etc/tdarr/arr_config.env
    restart: unless-stopped
```

---

**Configuration Complete!**