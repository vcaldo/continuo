# Playlist2SQLite Skill

OpenClaw skill for parsing M3U/M3U8 playlists into portable SQL dump files and **intelligently searching for channels by program/event**.

**Optimized for very large playlists (100k+ entries)** with reliable downloads, retry logic, and progress indicators.

## Structure

```
playlist2sqlite/
├── SKILL.md                      # Skill definition (loaded by OpenClaw)
├── scripts/
│   ├── playlist2sqlite.sh        # Main parsing script
│   └── search-channel.sh         # Intelligent channel search
└── README.md                     # This file (repo documentation)
```

## Installation

To use this skill in OpenClaw:

1. Package the skill:
```bash
# From continuo root
cd skills_scripts/playlist2sqlite
zip -r playlist2sqlite.skill *
```

2. Install in OpenClaw:
```bash
openclaw skills install playlist2sqlite.skill
```

Or manually copy to `~/.openclaw/skills/playlist2sqlite/`

## Quick Start

```bash
# Parse from URL
./scripts/playlist2sqlite.sh --url "https://provider.com/iptv.m3u" --name my-iptv

# Parse from local file
./scripts/playlist2sqlite.sh --input playlist.m3u --name channels

# For very large playlists
./scripts/playlist2sqlite.sh --url "https://large-provider.com/huge.m3u" --name huge \
    --timeout 3600 --verbose

# Import into SQLite
sqlite3 channels.db < channels.sql

# 🔍 Search for channels by program/event
./scripts/search-channel.sh --db channels.db --query "jogo do Barça"
./scripts/search-channel.sh --db channels.db --query "Champions League" --country BR

# 📺 Generate M3U playlist with search results
./scripts/search-channel.sh --db channels.db --query "BBB" --m3u bbb-channels.m3u
./scripts/search-channel.sh --db channels.db --query "futebol" --m3u soccer.m3u --max 20

# JSON output for integration
./scripts/search-channel.sh --db channels.db --query "NBA Finals" --json
```

## Features

- **Reliable downloads**: Automatic retry logic, configurable timeout
- **Large file support**: Progress indicators, memory-efficient streaming parser
- **Robust parsing**: Handles special characters, unicode, edge cases
- **SQL safety**: Proper escaping for all values
- **Transaction wrapping**: Fast database imports
- **Error handling**: Graceful cleanup on errors, informative messages
- **🔍 Intelligent search**: Find channels by program/event with web search + fuzzy matching

## Testing

Test the script directly:

```bash
# Create sample M3U
cat > test.m3u << 'EOF'
#EXTM3U
#EXTINF:-1 tvg-id="test1" tvg-name="Test Channel" tvg-logo="http://logo.png" group-title="Test",Test Channel
http://stream.url/test
#EXTINF:-1 tvg-id="test2" tvg-name="Channel with 'quotes'" group-title="Special",Quotes Test
http://stream.url/test2
EOF

# Parse from local file
./scripts/playlist2sqlite.sh --input test.m3u --name test --verbose

# Import and query
sqlite3 test.db < test.sql
sqlite3 test.db "SELECT * FROM channels;"

# Cleanup
rm -f test.m3u test.sql test.db
```

### Testing Large File Handling

```bash
# Generate a large test file (10k entries)
{
    echo "#EXTM3U"
    for i in $(seq 1 10000); do
        echo "#EXTINF:-1 tvg-id=\"ch$i\" tvg-name=\"Channel $i\" group-title=\"Group$((i % 10))\",Channel $i"
        echo "http://example.com/stream$i"
    done
} > large-test.m3u

# Parse with progress
./scripts/playlist2sqlite.sh --input large-test.m3u --name large-test --progress

# Verify
sqlite3 large-test.db < large-test.sql
sqlite3 large-test.db "SELECT COUNT(*) FROM channels;"  # Should show 10000
sqlite3 large-test.db "SELECT group_title, COUNT(*) FROM channels GROUP BY group_title;"

# Cleanup
rm -f large-test.m3u large-test.sql large-test.db
```

### Testing Channel Search

```bash
# Create test database with sample sports channels
sqlite3 test_channels.db << 'EOF'
CREATE TABLE IF NOT EXISTS channels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tvg_id TEXT, tvg_name TEXT, tvg_logo TEXT,
    group_title TEXT, url TEXT NOT NULL, raw_extinf TEXT
);
INSERT INTO channels (tvg_name, group_title, url) VALUES
    ('ESPN Brasil HD', 'Sports', 'http://stream.example.com/espn-br'),
    ('ESPN 2 HD', 'Sports', 'http://stream.example.com/espn2'),
    ('TNT Sports', 'Sports', 'http://stream.example.com/tnt'),
    ('SporTV HD', 'Sports BR', 'http://stream.example.com/sportv'),
    ('Premiere FC', 'Sports BR', 'http://stream.example.com/premiere'),
    ('GloboNews', 'News BR', 'http://stream.example.com/globonews'),
    ('HBO HD', 'Movies', 'http://stream.example.com/hbo');
EOF

# Test searches
./scripts/search-channel.sh --db test_channels.db --query "jogo do Barça"
./scripts/search-channel.sh --db test_channels.db --query "Champions League" --verbose
./scripts/search-channel.sh --db test_channels.db --query "notícias" --json

# Cleanup
rm -f test_channels.db
```

## Output

The script produces a `.sql` file (SQL dump) that can be imported into any SQLite database:

```bash
# Creates: my-iptv.sql
./scripts/playlist2sqlite.sh --url "https://..." --name my-iptv

# Import into database
sqlite3 my-iptv.db < my-iptv.sql
```

## Options Reference

### playlist2sqlite.sh

| Option | Description | Default |
|--------|-------------|---------|
| `--name NAME` | Output file name (required) | - |
| `--input FILE` | M3U file to parse | - |
| `--url URL` | M3U URL to download | - |
| `--append` | Append to existing SQL | false |
| `--verbose` | Show detailed progress | false |
| `--progress` | Show download/parse progress | auto for large files |
| `--timeout SECS` | Max download time | 1800 (30 min) |
| `--retries N` | Download retry count | 3 |

### search-channel.sh

| Option | Description | Default |
|--------|-------------|---------|
| `--db FILE` | SQLite database file (required) | - |
| `--query TEXT` | Event/program to search (required) | - |
| `--country CODE` | Country filter (BR, US, ES, etc.) | - |
| `--lang LANG` | Search language (pt, es, en) | pt |
| `--max N` | Maximum results | 10 |
| `--json` | Output as JSON | false |
| `--m3u FILE` | Also generate M3U playlist with results | - |
| `--verbose` | Show detailed progress | false |
| `--no-cache` | Skip web search cache | false |

## Troubleshooting

### Common Issues

1. **Download timeout**: Increase with `--timeout 3600` (1 hour)
2. **Download fails repeatedly**: Check URL accessibility, increase `--retries 5`
3. **HTML instead of M3U**: URL returned error page; verify URL works in browser
4. **Slow parsing**: Use `--progress` to see status; consider running on SSD
5. **Import fails**: Ensure SQLite has enough memory for large files

### Debugging

```bash
# Verbose mode shows detailed progress
./scripts/playlist2sqlite.sh --url "..." --name test --verbose

# Check downloaded content manually
curl -L "URL" | head -20

# Validate generated SQL
head -100 output.sql
sqlite3 :memory: < output.sql  # Should complete without errors
```

## Development

When updating the skill:

1. Edit `SKILL.md` or `scripts/playlist2sqlite.sh`
2. Test changes with sample M3U files
3. Test with large files (10k+ entries)
4. Re-package and reinstall in OpenClaw
5. Commit to repo

### Code Quality

The script follows these practices:
- `set -euo pipefail` for strict error handling
- Trap for cleanup on any exit
- Input validation before processing
- Proper SQL escaping for all edge cases
- Progress feedback for long operations

## License

Part of the continuo project.
