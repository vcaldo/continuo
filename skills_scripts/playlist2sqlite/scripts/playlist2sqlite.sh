#!/bin/bash
# playlist2sqlite.sh - Parse M3U playlist into SQL dump file
set -euo pipefail

# Default values
INPUT_FILE=""
INPUT_URL=""
OUTPUT_NAME=""
APPEND_MODE=false
VERBOSE=false
TEMP_FILE=""

# Cleanup function
cleanup() {
    if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
        log "Cleaned up temp file: $TEMP_FILE"
    fi
}
trap cleanup EXIT

# Usage function
usage() {
    cat << EOF
Usage: $0 --name NAME (--input FILE | --url URL) [OPTIONS]

Parse M3U/M3U8 playlist files and export as SQL dump file.

Required:
  --name NAME        Output file name (creates NAME.sql)
  --input FILE       M3U/M3U8 file to parse (mutually exclusive with --url)
  --url URL          M3U/M3U8 URL to download and parse (mutually exclusive with --input)

Options:
  --append           Append to existing SQL file (default: recreate)
  --verbose          Show detailed progress
  --help             Display this help message

Examples:
  $0 --url "https://provider.com/iptv.m3u" --name my-iptv
  $0 --input playlist.m3u --name channels
  $0 --input new.m3u --name channels --append
  $0 --url "https://example.com/streams.m3u" --name streams --verbose

Output:
  Creates NAME.sql file (portable SQL dump)

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
        --url)
            INPUT_URL="$2"
            shift 2
            ;;
        --name)
            OUTPUT_NAME="$2"
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
if [[ -z "$OUTPUT_NAME" ]]; then
    echo "Error: --name is required"
    echo "Run '$0 --help' for usage information."
    exit 1
fi

if [[ -z "$INPUT_FILE" && -z "$INPUT_URL" ]]; then
    echo "Error: Either --input or --url is required"
    echo "Run '$0 --help' for usage information."
    exit 1
fi

if [[ -n "$INPUT_FILE" && -n "$INPUT_URL" ]]; then
    echo "Error: --input and --url are mutually exclusive"
    echo "Run '$0 --help' for usage information."
    exit 1
fi

# Check dependencies
for cmd in sqlite3 sed awk grep; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: Required command not found: $cmd"
        exit 1
    fi
done

# Check curl if URL mode
if [[ -n "$INPUT_URL" ]]; then
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required for --url mode"
        exit 1
    fi
fi

# Log function
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
    fi
}

# Handle URL download
if [[ -n "$INPUT_URL" ]]; then
    TEMP_FILE=$(mktemp --suffix=.m3u)
    log "Downloading M3U from: $INPUT_URL"
    if ! curl -fsSL "$INPUT_URL" -o "$TEMP_FILE"; then
        echo "Error: Failed to download M3U from: $INPUT_URL"
        exit 1
    fi
    INPUT_FILE="$TEMP_FILE"
    log "Downloaded to temp file: $TEMP_FILE"
fi

# Validate input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Output file
SQL_FILE="${OUTPUT_NAME}.sql"

# Create/reset SQL file
if [[ "$APPEND_MODE" == false ]]; then
    log "Creating new SQL file: $SQL_FILE"
    rm -f "$SQL_FILE"
fi

log "Initializing database schema..."

# Build database in memory and dump to SQL
{
    # Schema
    cat << 'EOSQL'
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
        echo "-- Warning: File does not start with #EXTM3U header" >&2
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
                ((SKIPPED++)) || true
                continue
            fi
            
            # Escape single quotes for SQL
            TVG_ID_ESC=$(echo "$TVG_ID" | sed "s/'/''/g")
            TVG_NAME_ESC=$(echo "$TVG_NAME" | sed "s/'/''/g")
            TVG_LOGO_ESC=$(echo "$TVG_LOGO" | sed "s/'/''/g")
            GROUP_TITLE_ESC=$(echo "$GROUP_TITLE" | sed "s/'/''/g")
            URL_ESC=$(echo "$URL_LINE" | sed "s/'/''/g")
            EXTINF_ESC=$(echo "$EXTINF_LINE" | sed "s/'/''/g")
            
            # Generate INSERT statement
            echo "INSERT INTO channels (tvg_id, tvg_name, tvg_logo, group_title, url, raw_extinf) VALUES ("
            echo "    $([ -n "$TVG_ID" ] && echo "'$TVG_ID_ESC'" || echo "NULL"),"
            echo "    $([ -n "$TVG_NAME" ] && echo "'$TVG_NAME_ESC'" || echo "NULL"),"
            echo "    $([ -n "$TVG_LOGO" ] && echo "'$TVG_LOGO_ESC'" || echo "NULL"),"
            echo "    $([ -n "$GROUP_TITLE" ] && echo "'$GROUP_TITLE_ESC'" || echo "NULL"),"
            echo "    '$URL_ESC',"
            echo "    '$EXTINF_ESC'"
            echo ");"
            
            ((COUNT++)) || true
            log "Processed: $TVG_NAME ($URL_LINE)"
        fi
    done < "$INPUT_FILE"

    # Write count as comment at end
    echo ""
    echo "-- Channels inserted: $COUNT"
    if [[ $SKIPPED -gt 0 ]]; then
        echo "-- Entries skipped: $SKIPPED"
    fi

} > "$SQL_FILE"

# Get actual count from file
FINAL_COUNT=$(grep -c "^INSERT INTO channels" "$SQL_FILE" || echo "0")

# Summary
echo "==============================================="
echo "Parsing complete!"
echo "SQL file: $SQL_FILE"
echo "Channels added: $FINAL_COUNT"
echo "==============================================="

# Show usage examples
echo ""
echo "Usage examples:"
echo "  # Import into SQLite database:"
echo "  sqlite3 channels.db < $SQL_FILE"
echo ""
echo "  # Query after import:"
echo "  sqlite3 channels.db \"SELECT COUNT(*) FROM channels;\""
echo "  sqlite3 channels.db \"SELECT group_title, COUNT(*) FROM channels GROUP BY group_title;\""
