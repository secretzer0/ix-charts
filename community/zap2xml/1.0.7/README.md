# zap2xml

zap2xml fetches TV guide data from Zap2it and outputs XMLTV files for use with DVR software like Jellyfin, Plex, or Channels.

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `zap2xmlConfig.outputFile` | Path to output XMLTV file | `/xmltv/xmltv.xml` |
| `zap2xmlConfig.lineupId` | Zap2it lineup ID | `USA-OTA78735` |
| `zap2xmlConfig.timespan` | Hours of guide data to fetch | `168` |
| `zap2xmlConfig.postalCode` | Postal/ZIP code | `78735` |
| `zap2xmlConfig.sleepTime` | Seconds between updates | `21600` |

## Storage

The chart creates an ixVolume for the XMLTV output by default. You can configure additional storage mounts as needed.

## Usage

Point your DVR software (Jellyfin, Plex, Channels, etc.) to the XMLTV file location to import guide data.
