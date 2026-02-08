#!/bin/bash
# search-channel.sh - Find channels broadcasting specific programs/events
# Uses web search to identify broadcasting channels, then fuzzy matches against local database
set -euo pipefail

# Default values
DB_FILE=""
QUERY=""
COUNTRY=""
LANGUAGE="pt"
MAX_RESULTS=10
VERBOSE=false
CACHE_DIR="${TMPDIR:-/tmp}/playlist2sqlite-cache"
CACHE_TTL=3600  # 1 hour cache
JSON_OUTPUT=false
SEARCH_API_URL="${SEARCH_API_URL:-}"  # Optional external search API

# Color codes (disabled if not tty)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

# Logging functions
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${CYAN}[$(date +'%H:%M:%S')]${NC} $*" >&2
    fi
}

error() {
    echo -e "${RED}Error:${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}Warning:${NC} $*" >&2
}

# Usage
usage() {
    cat << 'EOF'
Usage: search-channel.sh --db DATABASE --query "QUERY" [OPTIONS]

Find channels broadcasting specific programs or events by searching the web
for broadcasting information and matching against your local channel database.

Required:
  --db FILE          SQLite database file (created by playlist2sqlite.sh)
  --query "TEXT"     Event/program to search for (e.g., "jogo do Barça")

Options:
  --country CODE     Country filter: BR, US, ES, PT, etc. (affects search terms)
  --lang LANG        Search language: pt, es, en (default: pt)
  --max N            Maximum results to show (default: 10)
  --json             Output results as JSON
  --verbose          Show detailed progress
  --no-cache         Skip cache for web search
  --help             Display this help

Examples:
  # Find channels showing Barcelona match
  ./search-channel.sh --db channels.db --query "jogo do Barça"
  
  # Search for Champions League in Brazil
  ./search-channel.sh --db channels.db --query "Champions League" --country BR
  
  # Find movie channels
  ./search-channel.sh --db channels.db --query "filme Gladiador" --lang pt
  
  # JSON output for integration
  ./search-channel.sh --db channels.db --query "NBA Finals" --json

How it works:
  1. Searches the web for "{query} onde assistir canais transmissão"
  2. Extracts channel names from search results (ESPN, TNT, Globo, etc.)
  3. Fuzzy matches found channels against your database
  4. Ranks results by match quality and sports relevance
  5. Returns top matches with stream URLs
EOF
    exit 0
}

# Parse arguments
USE_CACHE=true
while [[ $# -gt 0 ]]; do
    case $1 in
        --db)
            DB_FILE="$2"
            shift 2
            ;;
        --query)
            QUERY="$2"
            shift 2
            ;;
        --country)
            COUNTRY="$2"
            shift 2
            ;;
        --lang)
            LANGUAGE="$2"
            shift 2
            ;;
        --max)
            MAX_RESULTS="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --no-cache)
            USE_CACHE=false
            shift
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
if [[ -z "$DB_FILE" ]]; then
    error "--db is required"
    exit 1
fi

if [[ -z "$QUERY" ]]; then
    error "--query is required"
    exit 1
fi

if [[ ! -f "$DB_FILE" ]]; then
    error "Database file not found: $DB_FILE"
    exit 1
fi

# Check dependencies
for cmd in sqlite3 curl; do
    if ! command -v $cmd &> /dev/null; then
        error "Required command not found: $cmd"
        exit 1
    fi
done

# Create cache directory
mkdir -p "$CACHE_DIR"

# Known sports/news channels by region (for boosting matches)
declare -A KNOWN_SPORTS_CHANNELS=(
    # Brazil
    ["ESPN"]="sports"
    ["ESPN Brasil"]="sports"
    ["ESPN 2"]="sports"
    ["ESPN 3"]="sports"
    ["ESPN 4"]="sports"
    ["ESPN Extra"]="sports"
    ["Fox Sports"]="sports"
    ["TNT Sports"]="sports"
    ["SporTV"]="sports"
    ["SporTV 2"]="sports"
    ["SporTV 3"]="sports"
    ["Premiere"]="sports"
    ["BandSports"]="sports"
    ["Globo"]="general"
    ["Record"]="general"
    ["SBT"]="general"
    ["Band"]="general"
    ["RedeTV"]="general"
    # International
    ["beIN Sports"]="sports"
    ["Sky Sports"]="sports"
    ["DAZN"]="sports"
    ["NBC Sports"]="sports"
    ["CBS Sports"]="sports"
    ["Movistar"]="sports"
    ["Movistar Liga"]="sports"
    ["Movistar Deportes"]="sports"
    ["Star+"]="sports"
    ["Star Plus"]="sports"
    ["HBO"]="movies"
    ["HBO Max"]="movies"
    ["Max"]="movies"
    ["Netflix"]="movies"
    ["Prime Video"]="movies"
    ["Paramount+"]="movies"
    ["Disney+"]="movies"
    # News
    ["GloboNews"]="news"
    ["CNN"]="news"
    ["CNN Brasil"]="news"
    ["BBC"]="news"
)

# Common channel name patterns (for fuzzy matching)
CHANNEL_PATTERNS=(
    "ESPN" "Fox Sports" "TNT" "SporTV" "Premiere" "BandSports"
    "Globo" "Record" "SBT" "Band" "beIN" "Sky Sports" "DAZN"
    "HBO" "Star" "Paramount" "Disney" "Netflix" "Prime"
    "Movistar" "LaLiga" "La Liga" "Combate" "UFC" "Fight"
    "NBA" "NFL" "MLB" "NHL" "F1" "Formula"
    "Canal+" "Canal Plus" "Teledeporte" "Antena" "Cuatro"
    "Sport TV" "Eleven" "BT Sport" "Eurosport"
)

# Build search query based on language/country
build_search_query() {
    local query="$1"
    local lang="${2:-pt}"
    local country="${3:-}"
    
    local search_terms=""
    
    case "$lang" in
        pt)
            search_terms="$query onde assistir canal transmissão ao vivo"
            if [[ -n "$country" ]]; then
                search_terms="$search_terms $country"
            fi
            ;;
        es)
            search_terms="$query donde ver canal transmisión en vivo"
            if [[ -n "$country" ]]; then
                search_terms="$search_terms $country"
            fi
            ;;
        en)
            search_terms="$query where to watch channel broadcast live stream"
            if [[ -n "$country" ]]; then
                search_terms="$search_terms $country"
            fi
            ;;
        *)
            search_terms="$query channel broadcast live"
            ;;
    esac
    
    echo "$search_terms"
}

# Cache key for search
get_cache_key() {
    local query="$1"
    echo "$query" | md5sum | cut -d' ' -f1
}

# Check if cache is valid
is_cache_valid() {
    local cache_file="$1"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    local cache_time
    cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    local age=$((now - cache_time))
    
    if [[ $age -gt $CACHE_TTL ]]; then
        log "Cache expired (age: ${age}s)"
        return 1
    fi
    
    log "Using cached results (age: ${age}s)"
    return 0
}

# Perform DuckDuckGo HTML search (scraping)
search_duckduckgo() {
    local query="$1"
    local cache_key
    cache_key=$(get_cache_key "$query")
    local cache_file="$CACHE_DIR/ddg_$cache_key.html"
    
    if [[ "$USE_CACHE" == true ]] && is_cache_valid "$cache_file"; then
        cat "$cache_file"
        return 0
    fi
    
    log "Searching DuckDuckGo for: $query"
    
    local encoded_query
    encoded_query=$(echo "$query" | sed 's/ /+/g' | sed 's/[^a-zA-Z0-9+]/%&/g')
    
    local result
    result=$(curl -s -L \
        --max-time 30 \
        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
        -H "Accept-Language: pt-BR,pt;q=0.9,en;q=0.8" \
        "https://html.duckduckgo.com/html/?q=$encoded_query" 2>/dev/null || echo "")
    
    if [[ -n "$result" ]]; then
        echo "$result" > "$cache_file"
        echo "$result"
    else
        log "DuckDuckGo search failed"
        return 1
    fi
}

# Extract channel names from search results HTML
extract_channels_from_html() {
    local html="$1"
    local found_channels=()
    
    # Clean HTML and extract text snippets
    local text
    text=$(echo "$html" | \
        sed -e 's/<[^>]*>//g' \
            -e 's/&nbsp;/ /g' \
            -e 's/&amp;/\&/g' \
            -e 's/&lt;/</g' \
            -e 's/&gt;/>/g' \
            -e 's/&quot;/"/g' | \
        tr '[:upper:]' '[:lower:]')
    
    # Search for known channel patterns
    for pattern in "${CHANNEL_PATTERNS[@]}"; do
        local lower_pattern
        lower_pattern=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
        
        if echo "$text" | grep -qi "$lower_pattern"; then
            found_channels+=("$pattern")
            log "Found channel reference: $pattern"
        fi
    done
    
    # Also look for common broadcasting phrases and extract nearby channel names
    # Look for "transmite", "exibe", "passa", "transmitido", "disponível"
    local broadcast_snippets
    broadcast_snippets=$(echo "$html" | \
        grep -oiE '.{0,50}(transmit|exib|passa|disponível|watch|broadcast|stream|canal|channel).{0,100}' | \
        head -20)
    
    # Extract capitalized words that might be channel names
    local potential_channels
    potential_channels=$(echo "$broadcast_snippets" | \
        grep -oE '\b[A-Z][A-Za-z0-9+]*(\s+[A-Z][A-Za-z0-9+]*)?\b' | \
        sort -u | \
        head -30)
    
    while IFS= read -r channel; do
        [[ -z "$channel" ]] && continue
        # Filter out common non-channel words
        if ! echo "$channel" | grep -qiE '^(The|Where|Watch|Live|Free|Online|Streaming|Today|Match|Game|Play|How|What|When|Ver|Assistir|Onde|Como|Jogo|Partida|Ao|Vivo)$'; then
            if [[ ${#channel} -ge 2 && ${#channel} -le 30 ]]; then
                # Check if it matches known patterns
                for pattern in "${CHANNEL_PATTERNS[@]}"; do
                    if echo "$channel" | grep -qi "$pattern"; then
                        found_channels+=("$channel")
                        log "Found potential channel: $channel"
                        break
                    fi
                done
            fi
        fi
    done <<< "$potential_channels"
    
    # Remove duplicates and output
    printf '%s\n' "${found_channels[@]}" | sort -u
}

# Detect event type from query
detect_event_type() {
    local query="$1"
    local query_lower
    query_lower=$(echo "$query" | tr '[:upper:]' '[:lower:]')
    
    # Sports keywords
    if echo "$query_lower" | grep -qiE '(jogo|partida|match|game|futebol|football|soccer|basket|nba|nfl|mlb|nhl|f1|formula|ufc|boxing|boxe|luta|fight|tennis|tênis|golf|volei|volleyball|olimpiada|olympics|copa|cup|league|liga|champions|libertadores|euro|mundial|world)'; then
        echo "sports"
        return
    fi
    
    # Movie/Show keywords
    if echo "$query_lower" | grep -qiE '(filme|movie|series|série|show|novela|soap|drama|comedy|comédia|terror|horror|ação|action|documentário|documentary|estreia|premiere)'; then
        echo "entertainment"
        return
    fi
    
    # News keywords
    if echo "$query_lower" | grep -qiE '(notícia|news|jornal|debate|política|politics|eleição|election|cobertura|coverage)'; then
        echo "news"
        return
    fi
    
    echo "general"
}

# Calculate match score for a channel
calculate_score() {
    local channel_name="$1"
    local group_title="$2"
    local search_channel="$3"
    local event_type="$4"
    
    local score=0
    local channel_lower
    channel_lower=$(echo "$channel_name" | tr '[:upper:]' '[:lower:]')
    local search_lower
    search_lower=$(echo "$search_channel" | tr '[:upper:]' '[:lower:]')
    local group_lower
    group_lower=$(echo "$group_title" | tr '[:upper:]' '[:lower:]')
    
    # Exact match in name
    if [[ "$channel_lower" == "$search_lower" ]]; then
        score=$((score + 100))
    # Contains full search term
    elif [[ "$channel_lower" == *"$search_lower"* ]]; then
        score=$((score + 80))
    # Partial match (search term contained)
    elif [[ "$search_lower" == *"$channel_lower"* ]]; then
        score=$((score + 60))
    # Word-level match
    else
        for word in $search_lower; do
            if [[ ${#word} -ge 3 && "$channel_lower" == *"$word"* ]]; then
                score=$((score + 30))
            fi
        done
    fi
    
    # Boost for group matching event type
    case "$event_type" in
        sports)
            if echo "$group_lower" | grep -qiE '(sport|esporte|futebol|football|deportes|24/7)'; then
                score=$((score + 40))
            fi
            ;;
        entertainment)
            if echo "$group_lower" | grep -qiE '(movie|filme|series|série|entertainment|entretenimento|hbo|cinema)'; then
                score=$((score + 40))
            fi
            ;;
        news)
            if echo "$group_lower" | grep -qiE '(news|notícia|jornal|info)'; then
                score=$((score + 40))
            fi
            ;;
    esac
    
    # Boost for known channels
    for known in "${!KNOWN_SPORTS_CHANNELS[@]}"; do
        if [[ "$channel_lower" == *"$(echo "$known" | tr '[:upper:]' '[:lower:]')"* ]]; then
            local known_type="${KNOWN_SPORTS_CHANNELS[$known]}"
            if [[ "$known_type" == "$event_type" ]]; then
                score=$((score + 50))
            else
                score=$((score + 20))
            fi
            break
        fi
    done
    
    # Boost for HD/FHD channels
    if echo "$channel_lower" | grep -qiE '(hd|fhd|4k|uhd)'; then
        score=$((score + 10))
    fi
    
    echo "$score"
}

# Query database for matching channels
query_database() {
    local db="$1"
    local search_term="$2"
    local event_type="$3"
    shift 3
    local web_channels=("$@")
    
    local results=()
    local seen_urls=()
    
    log "Querying database for matches..."
    
    # First, search for channels found in web search
    for channel in "${web_channels[@]}"; do
        [[ -z "$channel" ]] && continue
        
        log "Searching for: $channel"
        
        # Prepare LIKE patterns
        local pattern
        pattern=$(echo "$channel" | sed "s/'/''/g")
        
        # Query with fuzzy matching
        local query_result
        query_result=$(sqlite3 -separator '|' "$db" "
            SELECT DISTINCT tvg_name, group_title, url
            FROM channels
            WHERE tvg_name LIKE '%$pattern%' COLLATE NOCASE
               OR group_title LIKE '%$pattern%' COLLATE NOCASE
            LIMIT 50
        " 2>/dev/null || echo "")
        
        while IFS='|' read -r name group url; do
            [[ -z "$name" || -z "$url" ]] && continue
            
            # Skip duplicates
            local skip=false
            for seen in "${seen_urls[@]}"; do
                if [[ "$seen" == "$url" ]]; then
                    skip=true
                    break
                fi
            done
            [[ "$skip" == true ]] && continue
            seen_urls+=("$url")
            
            # Calculate score
            local score
            score=$(calculate_score "$name" "$group" "$channel" "$event_type")
            
            if [[ $score -gt 0 ]]; then
                results+=("$score|$name|$group|$url|$channel")
                log "Match found: $name (score: $score)"
            fi
        done <<< "$query_result"
    done
    
    # Also search directly for the original query
    log "Searching database for original query: $search_term"
    
    # Split query into words for searching
    local words
    words=$(echo "$search_term" | tr ' ' '\n' | grep -E '.{2,}')
    
    for word in $words; do
        local pattern
        pattern=$(echo "$word" | sed "s/'/''/g")
        
        local query_result
        query_result=$(sqlite3 -separator '|' "$db" "
            SELECT DISTINCT tvg_name, group_title, url
            FROM channels
            WHERE tvg_name LIKE '%$pattern%' COLLATE NOCASE
            LIMIT 30
        " 2>/dev/null || echo "")
        
        while IFS='|' read -r name group url; do
            [[ -z "$name" || -z "$url" ]] && continue
            
            local skip=false
            for seen in "${seen_urls[@]}"; do
                if [[ "$seen" == "$url" ]]; then
                    skip=true
                    break
                fi
            done
            [[ "$skip" == true ]] && continue
            seen_urls+=("$url")
            
            local score
            score=$(calculate_score "$name" "$group" "$word" "$event_type")
            score=$((score / 2))  # Lower weight for direct query matches
            
            if [[ $score -gt 10 ]]; then
                results+=("$score|$name|$group|$url|$word")
            fi
        done <<< "$query_result"
    done
    
    # Sort by score descending and output
    printf '%s\n' "${results[@]}" | sort -t'|' -k1 -rn | head -"$MAX_RESULTS"
}

# Format output as pretty text
format_text_output() {
    local query="$1"
    shift
    local results=("$@")
    
    if [[ ${#results[@]} -eq 0 ]]; then
        echo ""
        echo -e "${YELLOW}No channels found for:${NC} \"$query\""
        echo ""
        echo "Suggestions:"
        echo "  - Try different search terms"
        echo "  - Check if your database contains the channels"
        echo "  - Use --verbose to see search details"
        return 0
    fi
    
    local count=${#results[@]}
    echo ""
    echo -e "${BOLD}Found $count possible channel(s) for:${NC} \"$query\""
    echo ""
    
    local rank=1
    for result in "${results[@]}"; do
        IFS='|' read -r score name group url matched_term <<< "$result"
        
        # Stars based on score
        local stars=""
        if [[ $score -ge 150 ]]; then
            stars="⭐⭐⭐"
        elif [[ $score -ge 100 ]]; then
            stars="⭐⭐"
        elif [[ $score -ge 50 ]]; then
            stars="⭐"
        fi
        
        echo -e "${BOLD}$rank.${NC} [$stars] ${GREEN}$name${NC}"
        echo -e "   ${CYAN}Category:${NC} ${group:-N/A}"
        echo -e "   ${CYAN}URL:${NC} $url"
        if [[ "$VERBOSE" == true ]]; then
            echo -e "   ${CYAN}Matched:${NC} $matched_term (score: $score)"
        fi
        echo ""
        
        ((rank++))
    done
}

# Format output as JSON
format_json_output() {
    local query="$1"
    shift
    local results=("$@")
    
    echo "{"
    echo "  \"query\": \"$query\","
    echo "  \"count\": ${#results[@]},"
    echo "  \"results\": ["
    
    local first=true
    for result in "${results[@]}"; do
        IFS='|' read -r score name group url matched_term <<< "$result"
        
        if [[ "$first" != true ]]; then
            echo ","
        fi
        first=false
        
        # Escape JSON strings
        name=$(echo "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')
        group=$(echo "$group" | sed 's/\\/\\\\/g; s/"/\\"/g')
        url=$(echo "$url" | sed 's/\\/\\\\/g; s/"/\\"/g')
        
        echo -n "    {"
        echo -n "\"name\": \"$name\", "
        echo -n "\"category\": \"${group:-null}\", "
        echo -n "\"url\": \"$url\", "
        echo -n "\"score\": $score"
        echo -n "}"
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

# Main execution
main() {
    log "Starting channel search..."
    log "Database: $DB_FILE"
    log "Query: $QUERY"
    log "Language: $LANGUAGE"
    [[ -n "$COUNTRY" ]] && log "Country: $COUNTRY"
    
    # Detect event type
    local event_type
    event_type=$(detect_event_type "$QUERY")
    log "Detected event type: $event_type"
    
    # Build search query
    local search_query
    search_query=$(build_search_query "$QUERY" "$LANGUAGE" "$COUNTRY")
    log "Search query: $search_query"
    
    # Perform web search
    local search_html=""
    search_html=$(search_duckduckgo "$search_query" 2>/dev/null || echo "")
    
    # Extract channels from search results
    local web_channels=()
    if [[ -n "$search_html" ]]; then
        while IFS= read -r channel; do
            [[ -n "$channel" ]] && web_channels+=("$channel")
        done < <(extract_channels_from_html "$search_html")
        log "Found ${#web_channels[@]} channel references from web search"
    else
        log "Web search returned no results, using pattern-based search"
    fi
    
    # If no web channels found, use known sports channels as fallback
    if [[ ${#web_channels[@]} -eq 0 ]]; then
        log "Using known channel patterns as fallback"
        for pattern in "${CHANNEL_PATTERNS[@]}"; do
            web_channels+=("$pattern")
        done
    fi
    
    # Query database
    local results=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && results+=("$line")
    done < <(query_database "$DB_FILE" "$QUERY" "$event_type" "${web_channels[@]}")
    
    # Output results
    if [[ "$JSON_OUTPUT" == true ]]; then
        format_json_output "$QUERY" "${results[@]}"
    else
        format_text_output "$QUERY" "${results[@]}"
    fi
}

main
