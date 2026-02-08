#!/bin/bash
# playlist2sqlite.sh - Parse M3U playlist into SQLite database
set -euo pipefail

# Default values
INPUT_FILE=""
DB_FILE=""
APPEND_MODE=false
VERBOSE=false

# Usage function
usage() {
    cat << EOF
Usage: $0 --input FILE --db FILE [OPTIONS]

Parse M3U/M3U8 playlist files and store in SQLite database.

Required:
  --input FILE       M3U/M3U8 file to parse
  --db FILE          SQLite database file path

Options:
  --append           Append to existing database (default: recreate)
  --verbose          Show detailed progress
  --help             Display this help message

Examples:
  $0 --input playlist.m3u --db channels.db
  $0 --input new.m3u --db channels.db --append
  $0 --input iptv.m3u --db iptv.db --verbose

Database Schema:
  Table: channels
  Columns: id, tvg_id, tvg_name, tvg_logo, group_title, url, raw_extinf
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --input)
            INPUT_FILE="$2"
            shift 2
            ;;
        --db)
            DB_FILE="$2"
            shift 2
            ;;
        --append)
            APPEND_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo "Run '$0 --help' for usage information."
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$INPUT_FILE" || -z "$DB_FILE" ]]; then
    echo "Error: --input and --db are required"
    echo "Run '$0 --help' for usage information."
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Check dependencies
for cmd in sqlite3 sed awk grep; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: Required command not found: $cmd"
        exit 1
    fi
done

# Log function
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
    fi
}

# Create/reset database
if [[ "$APPEND_MODE" == false ]]; then
    log "Creating new database: $DB_FILE"
    rm -f "$DB_FILE"
fi

log "Initializing database schema..."
sqlite3 "$DB_FILE" << 'EOSQL'
CREATE TABLE IF NOT EXISTS channels (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tvg_id TEXT,
    tvg_name TEXT,
    tvg_logo TEXT,
    group_title TEXT,
    url TEXT NOT NULL,
    raw_extinf TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_tvg_id ON channels(tvg_id);
CREATE INDEX IF NOT EXISTS idx_group_title ON channels(group_title);
EOSQL

log "Parsing M3U file: $INPUT_FILE"

# Validate M3U header
if ! head -n 1 "$INPUT_FILE" | grep -q "^#EXTM3U"; then
    echo "Warning: File does not start with #EXTM3U header. Proceeding anyway..."
fi

# Parse M3U file
COUNT=0
SKIPPED=0

# Read file line by line, processing EXTINF + URL pairs
while IFS= read -r line; do
    # Skip empty lines and comments (except EXTINF)
    if [[ -z "$line" || "$line" =~ ^#[^E] ]]; then
        continue
    fi

    # Process EXTINF line
    if [[ "$line" =~ ^#EXTINF ]]; then
        EXTINF_LINE="$line"
        
        # Extract attributes using sed/grep
        TVG_ID=$(echo "$line" | sed -n 's/.*tvg-id="\([^"]*\)".*/\1/p')
        TVG_NAME=$(echo "$line" | sed -n 's/.*tvg-name="\([^"]*\)".*/\1/p')
        TVG_LOGO=$(echo "$line" | sed -n 's/.*tvg-logo="\([^"]*\)".*/\1/p')
        GROUP_TITLE=$(echo "$line" | sed -n 's/.*group-title="\([^"]*\)".*/\1/p')
        
        # Read next line (URL)
        read -r URL_LINE || break
        
        # Skip if URL is empty or another EXTINF
        if [[ -z "$URL_LINE" || "$URL_LINE" =~ ^# ]]; then
            log "Skipping entry (no URL): $TVG_NAME"
            ((SKIPPED++))
            continue
        fi
        
        # Insert into database
        sqlite3 "$DB_FILE" << EOSQL
INSERT INTO channels (tvg_id, tvg_name, tvg_logo, group_title, url, raw_extinf)
VALUES (
    $([ -n "$TVG_ID" ] && echo "'$TVG_ID'" || echo "NULL"),
    $([ -n "$TVG_NAME" ] && echo "'$TVG_NAME'" || echo "NULL"),
    $([ -n "$TVG_LOGO" ] && echo "'$TVG_LOGO'" || echo "NULL"),
    $([ -n "$GROUP_TITLE" ] && echo "'$GROUP_TITLE'" || echo "NULL"),
    '$URL_LINE',
    '$(echo "$EXTINF_LINE" | sed "s/'/''/g")'
);
EOSQL
        
        ((COUNT++))
        log "Processed: $TVG_NAME ($URL_LINE)"
    fi
done < "$INPUT_FILE"

# Summary
echo "==============================================="
echo "Parsing complete!"
echo "Database: $DB_FILE"
echo "Channels added: $COUNT"
if [[ $SKIPPED -gt 0 ]]; then
    echo "Entries skipped: $SKIPPED"
fi
echo "==============================================="

# Show sample query
echo ""
echo "Query examples:"
echo "  sqlite3 $DB_FILE \"SELECT COUNT(*) FROM channels;\""
echo "  sqlite3 $DB_FILE \"SELECT group_title, COUNT(*) FROM channels GROUP BY group_title;\""
echo "  sqlite3 $DB_FILE \"SELECT tvg_name, url FROM channels WHERE group_title='Sports';\""
