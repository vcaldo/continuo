---
name: playlist2sqlite
description: Extract content from M3U playlist files and store in portable SQL format. Use when working with M3U/M3U8 playlists (IPTV, streaming URLs, media collections) and needing to parse, query, or analyze playlist metadata (channels, URLs, logos, groups, etc.). Supports both local files and URLs.
---

# Playlist2SQLite

Extract and parse M3U/M3U8 playlist files into portable SQL dump files for querying and analysis.

## Overview

M3U playlists (commonly used for IPTV, streaming services, and media collections) contain channel/stream metadata in a semi-structured text format. This skill provides a bash script to parse M3U files (from local files or URLs) and export as SQL dump files that can be imported into any SQLite database.

## Quick Start

```bash
# Parse from URL
scripts/playlist2sqlite.sh --url "https://provider.com/iptv.m3u" --name my-iptv

# Parse from local file
scripts/playlist2sqlite.sh --input playlist.m3u --name channels

# Append to existing SQL file
scripts/playlist2sqlite.sh --input new-channels.m3u --name channels --append

# Verbose mode
scripts/playlist2sqlite.sh --url "https://example.com/list.m3u" --name streams --verbose

# Import into SQLite database
sqlite3 channels.db < channels.sql
```

## Output Format

The script outputs a `.sql` file (SQL dump) containing:
- Table creation statements
- Index creation statements
- INSERT statements for each channel

This portable format can be imported into any SQLite database.

## Database Schema

The SQL creates a `channels` table with the following structure:

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
--name NAME        Output file name, creates NAME.sql (required)
--input FILE       M3U/M3U8 file to parse (mutually exclusive with --url)
--url URL          M3U/M3U8 URL to download and parse (mutually exclusive with --input)
--append           Append to existing SQL file (default: recreate)
--verbose          Show detailed progress
--help             Display usage information
```

### Examples

**From URL (most common):**
```bash
./scripts/playlist2sqlite.sh --url "https://provider.com/iptv.m3u" --name my-iptv
# Output: my-iptv.sql
```

**From local file:**
```bash
./scripts/playlist2sqlite.sh --input iptv.m3u --name channels
# Output: channels.sql
```

**Append new channels:**
```bash
./scripts/playlist2sqlite.sh --input additional.m3u --name channels --append
```

**With verbose output:**
```bash
./scripts/playlist2sqlite.sh --url "https://example.com/list.m3u" --name streams --verbose
```

## Importing the SQL

After generating the SQL file, import it into a SQLite database:

```bash
# Create new database and import
sqlite3 channels.db < channels.sql

# Or import into existing database
sqlite3 existing.db < channels.sql
```

## Querying the Database

After importing, query with standard SQLite:

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

1. **IPTV Management**: Parse provider playlists from URLs, filter/search channels, export subsets
2. **Playlist Analysis**: Count channels per group, identify missing metadata, find duplicates
3. **Playlist Merging**: Combine multiple M3U files into single database, deduplicate
4. **Channel Migration**: Extract channels from old format, transform, export to new format
5. **EPG Integration**: Use tvg-id to link channels with Electronic Program Guide data
6. **Backup**: Store playlist data in portable SQL format

## Notes

- Script requires `bash`, `sqlite3`, `curl` (for URL mode), and standard Unix tools (`sed`, `awk`, `grep`)
- Handles both M3U and M3U8 formats (M3U8 is UTF-8 encoded M3U)
- Non-standard EXTINF attributes are preserved in `raw_extinf` column
- Empty/invalid URLs are skipped with warning in verbose mode
- URL downloads use curl with automatic temp file cleanup
- Output is `.sql` file (SQL dump), not `.db` (SQLite binary)
