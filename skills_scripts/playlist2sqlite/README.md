# Playlist2SQLite Skill

OpenClaw skill for parsing M3U/M3U8 playlists into portable SQL dump files.

## Structure

```
playlist2sqlite/
├── SKILL.md                      # Skill definition (loaded by OpenClaw)
├── scripts/
│   └── playlist2sqlite.sh        # Main parsing script
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

# Import into SQLite
sqlite3 channels.db < channels.sql
```

## Testing

Test the script directly:

```bash
# Create sample M3U
cat > test.m3u << 'EOF'
#EXTM3U
#EXTINF:-1 tvg-id="test1" tvg-name="Test Channel" tvg-logo="http://logo.png" group-title="Test",Test Channel
http://stream.url/test
EOF

# Parse from local file
./scripts/playlist2sqlite.sh --input test.m3u --name test --verbose

# Import and query
sqlite3 test.db < test.sql
sqlite3 test.db "SELECT * FROM channels;"

# Test URL mode (with a public M3U if available)
./scripts/playlist2sqlite.sh --url "https://example.com/playlist.m3u" --name remote --verbose
sqlite3 remote.db < remote.sql
```

## Output

The script produces a `.sql` file (SQL dump) that can be imported into any SQLite database:

```bash
# Creates: my-iptv.sql
./scripts/playlist2sqlite.sh --url "https://..." --name my-iptv

# Import into database
sqlite3 my-iptv.db < my-iptv.sql
```

## Development

When updating the skill:

1. Edit `SKILL.md` or `scripts/playlist2sqlite.sh`
2. Test changes
3. Re-package and reinstall in OpenClaw
4. Commit to repo

## License

Part of the continuo project.
