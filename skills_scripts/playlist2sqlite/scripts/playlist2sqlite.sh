#!/bin/bash
# playlist2sqlite.sh - Parse M3U playlist into SQL dump file
# Optimized for very large playlists (100k+ entries)
set -euo pipefail

# Default values
INPUT_FILE=""
INPUT_URL=""
OUTPUT_NAME=""
APPEND_MODE=false
VERBOSE=false
TEMP_FILE=""
SHOW_PROGRESS=false

# Download settings (for large playlists)
CONNECT_TIMEOUT=30
MAX_TIME=1800  # 30 minutes max for very large playlists
RETRY_COUNT=3
RETRY_DELAY=5

# Size thresholds
LARGE_FILE_THRESHOLD=$((50 * 1024 * 1024))  # 50MB = large file warning
VERY_LARGE_FILE_THRESHOLD=$((200 * 1024 * 1024))  # 200MB = very large file warning

# Cleanup function - always runs on exit
cleanup() {
    local exit_code=$?
    if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
        log "Cleaned up temp file: $TEMP_FILE"
    fi
    exit $exit_code
}
trap cleanup EXIT INT TERM

# Log function
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
    fi
}

# Progress function (always shows for large operations)
progress() {
    if [[ "$VERBOSE" == true || "$SHOW_PROGRESS" == true ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
    fi
}

# Error function
error() {
    echo "Error: $*" >&2
}

# Warning function
warn() {
    echo "Warning: $*" >&2
}

# Usage function
usage() {
    cat << EOF
Usage: $0 --name NAME (--input FILE | --url URL) [OPTIONS]

Parse M3U/M3U8 playlist files and export as SQL dump file.
Optimized for very large playlists (100k+ entries).

Required:
  --name NAME        Output file name (creates NAME.sql)
  --input FILE       M3U/M3U8 file to parse (mutually exclusive with --url)
  --url URL          M3U/M3U8 URL to download and parse (mutually exclusive with --input)

Options:
  --append           Append to existing SQL file (default: recreate)
  --verbose          Show detailed progress
  --progress         Show download/parsing progress (auto-enabled for large files)
  --timeout SECS     Max download time in seconds (default: $MAX_TIME)
  --retries N        Number of download retries (default: $RETRY_COUNT)
  --help             Display this help message

Examples:
  $0 --url "https://provider.com/iptv.m3u" --name my-iptv
  $0 --input playlist.m3u --name channels
  $0 --input new.m3u --name channels --append
  $0 --url "https://example.com/large.m3u" --name streams --verbose --timeout 3600

Output:
  Creates NAME.sql file (portable SQL dump)

Database Schema:
  Table: channels
  Columns: id, tvg_id, tvg_name, tvg_logo, group_title, url, raw_extinf

Notes:
  - Large files (>50MB) automatically show progress
  - Downloads include retry logic for reliability
  - Temp files are cleaned up even on errors
  - SQL escaping handles quotes, newlines, and unicode
EOF
    exit 0
}

# Escape string for SQL (handles quotes, newlines, and special chars)
sql_escape() {
    local input="$1"
    # Replace single quotes with two single quotes (SQL standard)
    # Also handle embedded newlines and carriage returns
    printf '%s' "$input" | sed -e "s/'/''/g" -e ':a;N;$!ba;s/\n/\\n/g' -e 's/\r/\\r/g'
}

# Validate M3U file content
validate_m3u() {
    local file="$1"
    local first_line
    
    # Check file exists and is readable
    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi
    
    if [[ ! -r "$file" ]]; then
        error "File not readable: $file"
        return 1
    fi
    
    # Check file is not empty
    if [[ ! -s "$file" ]]; then
        error "File is empty: $file"
        return 1
    fi
    
    # Read first line
    first_line=$(head -n 1 "$file")
    
    # Check for HTML error pages (common when download fails)
    if [[ "$first_line" =~ ^\<\!DOCTYPE || "$first_line" =~ ^\<html || "$first_line" =~ ^\<HTML ]]; then
        error "Downloaded file appears to be HTML (possibly an error page)"
        error "First line: ${first_line:0:100}"
        return 1
    fi
    
    # Check for JSON error responses
    if [[ "$first_line" =~ ^\{ && "$first_line" =~ \"error\" ]]; then
        error "Downloaded file appears to be a JSON error response"
        error "Content: ${first_line:0:200}"
        return 1
    fi
    
    # Check for M3U header (warn but don't fail - some M3U files lack header)
    if [[ ! "$first_line" =~ ^#EXTM3U ]]; then
        warn "File does not start with #EXTM3U header - may not be valid M3U"
        # Check if file contains any EXTINF lines
        if ! grep -q "^#EXTINF" "$file"; then
            error "File contains no #EXTINF entries - not a valid M3U file"
            return 1
        fi
    fi
    
    return 0
}

# Download with retry logic
download_with_retry() {
    local url="$1"
    local output="$2"
    local attempt=1
    local curl_opts=()
    
    # Build curl options
    curl_opts+=(
        --fail                          # Fail on HTTP errors
        --location                      # Follow redirects
        --connect-timeout "$CONNECT_TIMEOUT"
        --max-time "$MAX_TIME"
        --retry "$RETRY_COUNT"
        --retry-delay "$RETRY_DELAY"
        --retry-connrefused
        --output "$output"
    )
    
    # Add progress bar for large downloads (when verbose or progress mode)
    if [[ "$VERBOSE" == true || "$SHOW_PROGRESS" == true ]]; then
        curl_opts+=(--progress-bar)
    else
        curl_opts+=(--silent --show-error)
    fi
    
    progress "Downloading M3U from: $url"
    progress "Timeout: ${MAX_TIME}s, Retries: $RETRY_COUNT"
    
    # Download with retry
    while [[ $attempt -le $RETRY_COUNT ]]; do
        if curl "${curl_opts[@]}" "$url"; then
            # Verify download completed (file exists and has content)
            if [[ -s "$output" ]]; then
                local size
                size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "0")
                progress "Download complete: $(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size} bytes")"
                return 0
            else
                warn "Download produced empty file (attempt $attempt/$RETRY_COUNT)"
            fi
        else
            warn "Download failed (attempt $attempt/$RETRY_COUNT)"
        fi
        
        if [[ $attempt -lt $RETRY_COUNT ]]; then
            progress "Retrying in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi
        ((attempt++))
    done
    
    error "Download failed after $RETRY_COUNT attempts"
    return 1
}

# Check file size and warn if large
check_file_size() {
    local file="$1"
    local size
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
    
    if [[ $size -gt $VERY_LARGE_FILE_THRESHOLD ]]; then
        warn "Very large file detected: $(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size} bytes")"
        warn "Processing may take several minutes and use significant memory"
        SHOW_PROGRESS=true
    elif [[ $size -gt $LARGE_FILE_THRESHOLD ]]; then
        progress "Large file detected: $(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size} bytes")"
        SHOW_PROGRESS=true
    else
        log "File size: $(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size} bytes")"
    fi
    
    echo "$size"
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
        --progress)
            SHOW_PROGRESS=true
            shift
            ;;
        --timeout)
            MAX_TIME="$2"
            shift 2
            ;;
        --retries)
            RETRY_COUNT="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            echo "Run '$0 --help' for usage information." >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$OUTPUT_NAME" ]]; then
    error "--name is required"
    echo "Run '$0 --help' for usage information." >&2
    exit 1
fi

if [[ -z "$INPUT_FILE" && -z "$INPUT_URL" ]]; then
    error "Either --input or --url is required"
    echo "Run '$0 --help' for usage information." >&2
    exit 1
fi

if [[ -n "$INPUT_FILE" && -n "$INPUT_URL" ]]; then
    error "--input and --url are mutually exclusive"
    echo "Run '$0 --help' for usage information." >&2
    exit 1
fi

# Check dependencies
for cmd in sqlite3 sed awk grep head; do
    if ! command -v $cmd &> /dev/null; then
        error "Required command not found: $cmd"
        exit 1
    fi
done

# Check curl if URL mode
if [[ -n "$INPUT_URL" ]]; then
    if ! command -v curl &> /dev/null; then
        error "curl is required for --url mode"
        exit 1
    fi
fi

# Handle URL download
if [[ -n "$INPUT_URL" ]]; then
    TEMP_FILE=$(mktemp --suffix=.m3u)
    log "Created temp file: $TEMP_FILE"
    
    if ! download_with_retry "$INPUT_URL" "$TEMP_FILE"; then
        exit 1
    fi
    
    INPUT_FILE="$TEMP_FILE"
fi

# Validate input file
if ! validate_m3u "$INPUT_FILE"; then
    exit 1
fi

# Check file size
FILE_SIZE=$(check_file_size "$INPUT_FILE")

# Output file
SQL_FILE="${OUTPUT_NAME}.sql"

# Create/reset SQL file
if [[ "$APPEND_MODE" == false ]]; then
    log "Creating new SQL file: $SQL_FILE"
    rm -f "$SQL_FILE"
fi

progress "Parsing M3U file..."

# Build database in memory and dump to SQL
{
    # Schema (only if not appending)
    if [[ "$APPEND_MODE" == false ]]; then
        cat << 'EOSQL'
-- Playlist2SQLite SQL Dump
-- Generated by playlist2sqlite.sh

BEGIN TRANSACTION;

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
    else
        echo "BEGIN TRANSACTION;"
        echo ""
    fi

    log "Parsing M3U file: $INPUT_FILE"

    # Parse M3U file
    COUNT=0
    SKIPPED=0
    PROGRESS_INTERVAL=1000  # Show progress every N entries
    LAST_PROGRESS_TIME=$(date +%s)

    # Read file line by line, processing EXTINF + URL pairs
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Skip comments (except EXTINF)
        [[ "$line" =~ ^#[^E] ]] && continue
        [[ "$line" =~ ^#EXT[^I] ]] && continue

        # Process EXTINF line
        if [[ "$line" =~ ^#EXTINF ]]; then
            EXTINF_LINE="$line"
            
            # Extract attributes using sed/grep (handle various quote styles)
            TVG_ID=$(echo "$line" | sed -n 's/.*tvg-id="\([^"]*\)".*/\1/p')
            TVG_NAME=$(echo "$line" | sed -n 's/.*tvg-name="\([^"]*\)".*/\1/p')
            TVG_LOGO=$(echo "$line" | sed -n 's/.*tvg-logo="\([^"]*\)".*/\1/p')
            GROUP_TITLE=$(echo "$line" | sed -n 's/.*group-title="\([^"]*\)".*/\1/p')
            
            # Read next line (URL)
            if ! IFS= read -r URL_LINE; then
                log "Skipping entry (EOF after EXTINF): $TVG_NAME"
                ((SKIPPED++)) || true
                continue
            fi
            
            # Skip empty URLs or lines that are comments/EXTINF
            if [[ -z "$URL_LINE" || "$URL_LINE" =~ ^# ]]; then
                log "Skipping entry (no URL): $TVG_NAME"
                ((SKIPPED++)) || true
                continue
            fi
            
            # Trim whitespace from URL
            URL_LINE="${URL_LINE#"${URL_LINE%%[![:space:]]*}"}"
            URL_LINE="${URL_LINE%"${URL_LINE##*[![:space:]]}"}"
            
            # Escape values for SQL (handles quotes, newlines, unicode)
            TVG_ID_ESC=$(sql_escape "$TVG_ID")
            TVG_NAME_ESC=$(sql_escape "$TVG_NAME")
            TVG_LOGO_ESC=$(sql_escape "$TVG_LOGO")
            GROUP_TITLE_ESC=$(sql_escape "$GROUP_TITLE")
            URL_ESC=$(sql_escape "$URL_LINE")
            EXTINF_ESC=$(sql_escape "$EXTINF_LINE")
            
            # Generate INSERT statement (compact format for efficiency)
            printf "INSERT INTO channels (tvg_id, tvg_name, tvg_logo, group_title, url, raw_extinf) VALUES (%s, %s, %s, %s, '%s', '%s');\n" \
                "$([ -n "$TVG_ID" ] && echo "'$TVG_ID_ESC'" || echo "NULL")" \
                "$([ -n "$TVG_NAME" ] && echo "'$TVG_NAME_ESC'" || echo "NULL")" \
                "$([ -n "$TVG_LOGO" ] && echo "'$TVG_LOGO_ESC'" || echo "NULL")" \
                "$([ -n "$GROUP_TITLE" ] && echo "'$GROUP_TITLE_ESC'" || echo "NULL")" \
                "$URL_ESC" \
                "$EXTINF_ESC"
            
            ((COUNT++)) || true
            
            # Show progress for large files
            if [[ $((COUNT % PROGRESS_INTERVAL)) -eq 0 ]]; then
                NOW=$(date +%s)
                if [[ $((NOW - LAST_PROGRESS_TIME)) -ge 5 || "$VERBOSE" == true ]]; then
                    progress "Processed $COUNT entries..."
                    LAST_PROGRESS_TIME=$NOW
                fi
            fi
            
            log "Processed: $TVG_NAME"
        fi
    done < "$INPUT_FILE"

    # Commit transaction
    echo ""
    echo "COMMIT;"
    echo ""
    
    # Write stats as comments at end
    echo "-- ======================================="
    echo "-- Channels inserted: $COUNT"
    if [[ $SKIPPED -gt 0 ]]; then
        echo "-- Entries skipped: $SKIPPED"
    fi
    echo "-- Generated: $(date -Iseconds)"
    echo "-- ======================================="

} > "$SQL_FILE"

# Validate the generated SQL file
log "Validating generated SQL..."
if ! head -n 5 "$SQL_FILE" | grep -q "CREATE TABLE\|INSERT INTO\|BEGIN TRANSACTION"; then
    error "Generated SQL file appears invalid"
    exit 1
fi

# Get actual count from file
FINAL_COUNT=$(grep -c "^INSERT INTO channels" "$SQL_FILE" 2>/dev/null || echo "0")

# Verify SQL syntax with sqlite3 (dry run)
log "Verifying SQL syntax..."
if ! echo "EXPLAIN $(head -n 50 "$SQL_FILE" | grep "^INSERT INTO" | head -1)" | sqlite3 :memory: 2>/dev/null; then
    warn "Could not verify SQL syntax (non-fatal)"
fi

# Get output file size
OUTPUT_SIZE=$(stat -c%s "$SQL_FILE" 2>/dev/null || stat -f%z "$SQL_FILE" 2>/dev/null || echo "0")
OUTPUT_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "$OUTPUT_SIZE" 2>/dev/null || echo "${OUTPUT_SIZE} bytes")

# Summary
echo "==============================================="
echo "Parsing complete!"
echo "SQL file: $SQL_FILE ($OUTPUT_SIZE_HUMAN)"
echo "Channels added: $FINAL_COUNT"
if [[ $SKIPPED -gt 0 ]]; then
    echo "Entries skipped: $SKIPPED"
fi
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
