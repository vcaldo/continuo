# Playlist2SQLite Skill

OpenClaw skill for parsing M3U/M3U8 playlists into SQLite databases.

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

## Testing

Test the script directly:

```bash
# Create sample M3U
cat > test.m3u << 'EOF'
#EXTM3U
#EXTINF:-1 tvg-id="test1" tvg-name="Test Channel" tvg-logo="http://logo.png" group-title="Test",Test Channel
http://stream.url/test
EOF

# Parse it
./scripts/playlist2sqlite.sh --input test.m3u --db test.db --verbose

# Query result
sqlite3 test.db "SELECT * FROM channels;"
```

## Development

When updating the skill:

1. Edit `SKILL.md` or `scripts/playlist2sqlite.sh`
2. Test changes
3. Re-package and reinstall in OpenClaw
4. Commit to repo

## License

Part of the continuo project.
