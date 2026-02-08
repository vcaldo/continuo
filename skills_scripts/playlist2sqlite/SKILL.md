---
name: playlist2sqlite
description: Extract content from M3U playlist files and store in portable SQL format. Use when working with M3U/M3U8 playlists (IPTV, streaming URLs, media collections) and needing to parse, query, or analyze playlist metadata (channels, URLs, logos, groups, etc.). Supports both local files and URLs. Optimized for very large playlists (100k+ entries).
---

# Playlist2SQLite

Extract and parse M3U/M3U8 playlist files into portable SQL dump files for querying and analysis.

## Overview

M3U playlists (commonly used for IPTV, streaming services, and media collections) contain channel/stream metadata in a semi-structured text format. This skill provides a bash script to parse M3U files (from local files or URLs) and export as SQL dump files that can be imported into any SQLite database.

**Features:**
- Download large playlists reliably with retry logic
- Handle files with 100k+ entries
- Proper SQL escaping for all edge cases
- Progress indicators for large files
- Automatic cleanup on errors

## Quick Start

```bash
# Parse from URL
scripts/playlist2sqlite.sh --url "https://provider.com/iptv.m3u" --name my-iptv

# Parse from local file
scripts/playlist2sqlite.sh --input playlist.m3u --name channels

# Append to existing SQL file
scripts/playlist2sqlite.sh --input new-channels.m3u --name channels --append

# Verbose mode with progress
scripts/playlist2sqlite.sh --url "https://example.com/list.m3u" --name streams --verbose

# For very large playlists (increase timeout)
scripts/playlist2sqlite.sh --url "https://large-provider.com/huge.m3u" --name huge --timeout 3600 --progress

# Import into SQLite database
sqlite3 channels.db < channels.sql
```

## Output Format

The script outputs a `.sql` file (SQL dump) containing:
- Transaction wrapping for performance
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
--progress         Show download/parsing progress (auto-enabled for large files)
--timeout SECS     Max download time in seconds (default: 1800 = 30 minutes)
--retries N        Number of download retries (default: 3)
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

**Large playlist with extended timeout:**
```bash
./scripts/playlist2sqlite.sh --url "https://example.com/large.m3u" --name streams \
    --timeout 3600 --verbose
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

## Large Playlist Handling

The script is optimized for very large playlists:

### Automatic Optimizations
- **Progress indicators:** Automatically enabled for files >50MB
- **Transaction wrapping:** All inserts wrapped in transaction for faster imports
- **Retry logic:** Downloads automatically retry up to 3 times on failure
- **Memory efficiency:** Streaming parser (doesn't load entire file into memory)

### Recommended Settings for Large Playlists

| Playlist Size | Recommended Settings |
|--------------|---------------------|
| <10k entries | Default settings work fine |
| 10k-50k entries | Add `--progress` to see status |
| 50k-100k entries | Add `--timeout 3600 --verbose` |
| >100k entries | Add `--timeout 7200 --verbose`, consider running on fast storage |

### Example: 100k+ Entry Playlist
```bash
./scripts/playlist2sqlite.sh \
    --url "https://large-provider.com/mega.m3u" \
    --name mega-list \
    --timeout 7200 \
    --retries 5 \
    --verbose
```

## Troubleshooting

### Download Issues

**"Download failed after X attempts"**
- Check if URL is accessible: `curl -I "URL"`
- Increase timeout: `--timeout 3600`
- Increase retries: `--retries 5`
- Some providers rate-limit; wait and retry

**"Downloaded file appears to be HTML"**
- URL returned error page instead of M3U
- Check if URL requires authentication
- Verify URL is correct and not expired
- Try accessing URL in browser to see the actual error

**Slow downloads**
- Large playlists (>100MB) can take 10+ minutes on slow connections
- Use `--progress` to see download status
- Increase `--timeout` for slow connections

### Parsing Issues

**"File contains no #EXTINF entries"**
- File is not a valid M3U playlist
- Check file content: `head -20 file.m3u`
- May be wrong format (e.g., plain text URL list)

**"Entries skipped" in output**
- Normal for M3U files with malformed entries
- Use `--verbose` to see which entries were skipped
- Usually caused by missing URL after EXTINF line

**Special characters causing issues**
- Script handles quotes, newlines, and unicode automatically
- If import fails, check for unusual binary content in M3U

### Import Issues

**SQLite "database is locked"**
- Close other applications using the database
- For large imports, use: `sqlite3 -cmd ".timeout 30000" db.db < file.sql`

**Import very slow**
- The SQL file uses transactions, which should be fast
- Ensure database is on SSD, not spinning disk
- For very large files, import may take several minutes

**Out of memory**
- SQLite handles large imports well, but OS needs memory
- For 100k+ entries, ensure 1GB+ free RAM
- Consider splitting very large playlists

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
- URL downloads use curl with automatic retry and temp file cleanup
- Output is `.sql` file (SQL dump), not `.db` (SQLite binary)
- SQL is wrapped in transaction for faster imports
