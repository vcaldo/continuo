---
name: playlist2sqlite
description: Extract content from M3U playlist files and store in SQLite database. Use when working with M3U/M3U8 playlists (IPTV, streaming URLs, media collections) and needing to parse, query, or analyze playlist metadata (channels, URLs, logos, groups, etc.) in a structured database format.
---

# Playlist2SQLite

Extract and parse M3U/M3U8 playlist files into a SQLite database for querying and analysis.

## Overview

M3U playlists (commonly used for IPTV, streaming services, and media collections) contain channel/stream metadata in a semi-structured text format. This skill provides a bash script to parse M3U files and store entries in a SQLite database with structured fields.

## Quick Start

```bash
# Parse an M3U file and create/populate database
scripts/playlist2sqlite.sh --input playlist.m3u --db channels.db

# Append to existing database
scripts/playlist2sqlite.sh --input new-channels.m3u --db channels.db --append

# Verbose mode
scripts/playlist2sqlite.sh --input playlist.m3u --db channels.db --verbose
```

## Database Schema

The script creates a `channels` table with the following structure:

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PRIMARY KEY | Auto-increment ID |
| `tvg_id` | TEXT | TVG ID (EPG identifier) |
| `tvg_name` | TEXT | Channel name |
| `tvg_logo` | TEXT | Logo URL |
| `group_title` | TEXT | Channel group/category |
| `url` | TEXT | Stream URL |
| `raw_extinf` | TEXT | Full EXTINF line (for non-standard attributes) |

## M3U Format Reference

M3U files follow this structure:

```
#EXTM3U
#EXTINF:-1 tvg-id="channel1" tvg-name="Channel 1" tvg-logo="http://logo.png" group-title="News",Channel 1
http://stream.url/channel1
#EXTINF:-1 tvg-id="channel2" tvg-name="Channel 2" tvg-logo="http://logo2.png" group-title="Sports",Channel 2
http://stream.url/channel2
```

The script parses:
- `#EXTM3U` header (validates format)
- `#EXTINF` metadata lines (extracts tvg-*, group-title, channel name)
- Stream URLs (line immediately following EXTINF)

## Script Usage

Located at: `scripts/playlist2sqlite.sh`

### Options

```
--input FILE       M3U/M3U8 file to parse (required)
--db FILE          SQLite database path (required)
--append           Append to existing database (default: recreate)
--verbose          Show detailed progress
--help             Display usage information
```

### Examples

**Basic usage:**
```bash
./scripts/playlist2sqlite.sh --input iptv.m3u --db iptv.db
```

**Append new channels:**
```bash
./scripts/playlist2sqlite.sh --input additional.m3u --db iptv.db --append
```

**With verbose output:**
```bash
./scripts/playlist2sqlite.sh --input playlist.m3u --db channels.db --verbose
```

## Querying the Database

After parsing, query with standard SQLite:

```bash
# Count channels by group
sqlite3 channels.db "SELECT group_title, COUNT(*) FROM channels GROUP BY group_title;"

# Find all sports channels
sqlite3 channels.db "SELECT tvg_name, url FROM channels WHERE group_title LIKE '%Sport%';"

# Export specific group to CSV
sqlite3 -header -csv channels.db "SELECT * FROM channels WHERE group_title='Movies';" > movies.csv

# Find channels without logos
sqlite3 channels.db "SELECT tvg_name FROM channels WHERE tvg_logo IS NULL OR tvg_logo='';"
```

## Common Use Cases

1. **IPTV Management**: Parse provider playlists, filter/search channels, export subsets
2. **Playlist Analysis**: Count channels per group, identify missing metadata, find duplicates
3. **Playlist Merging**: Combine multiple M3U files into single database, deduplicate
4. **Channel Migration**: Extract channels from old format, transform, export to new format
5. **EPG Integration**: Use tvg-id to link channels with Electronic Program Guide data

## Notes

- Script requires `bash`, `sqlite3`, and standard Unix tools (`sed`, `awk`, `grep`)
- Handles both M3U and M3U8 formats (M3U8 is UTF-8 encoded M3U)
- Non-standard EXTINF attributes are preserved in `raw_extinf` column
- Empty/invalid URLs are skipped with warning in verbose mode
- Database is created if it doesn't exist
