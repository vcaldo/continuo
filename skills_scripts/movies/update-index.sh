#!/bin/bash

# update-index.sh - Update INDEX.md with all movies from the catalog
# This script scans to-watch/ and watched/ directories and generates an alphabetical index
#
# Usage: ./update-index.sh [REPO_DIR]
#   REPO_DIR defaults to /tmp/movies if not specified

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}" >&2; }

# Repository directory
REPO_DIR="${1:-/tmp/movies}"

# Strip leading article for sorting (The, A, An, O, Os, A, As, El, La, Los, Las)
strip_article() {
    local title="$1"
    # English articles
    title=$(echo "$title" | sed -E 's/^(The|A|An) //i')
    # Portuguese articles
    title=$(echo "$title" | sed -E 's/^(O|Os|A|As) //i')
    # Spanish articles
    title=$(echo "$title" | sed -E 's/^(El|La|Los|Las|Un|Una) //i')
    echo "$title"
}

# Extract title from markdown file
extract_title() {
    local file="$1"
    local title=""
    
    # Try YAML frontmatter first: title: "..."
    title=$(grep -m1 '^title:' "$file" 2>/dev/null | sed 's/^title:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//' || true)
    
    # If not found, try H1 header: # Title (Year) or # Title
    if [ -z "$title" ]; then
        title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' | sed 's/ ([0-9]\{4\})$//' || true)
    fi
    
    # Clean up
    title=$(echo "$title" | xargs)
    echo "$title"
}

# Extract year from markdown file
extract_year() {
    local file="$1"
    local year=""
    
    # Try YAML frontmatter: year: YYYY
    year=$(grep -m1 '^year:' "$file" 2>/dev/null | sed 's/^year:[[:space:]]*//' | grep -oE '[0-9]{4}' || true)
    
    # Try H1 header: # Title (YYYY)
    if [ -z "$year" ]; then
        year=$(grep -m1 '^# ' "$file" 2>/dev/null | grep -oE '\([0-9]{4}\)' | tr -d '()' || true)
    fi
    
    # Try list format: - **Year:** 1994 (colon inside bold)
    if [ -z "$year" ]; then
        year=$(grep -iE '[-*] \*\*(Year|Ano):\*\*' "$file" 2>/dev/null | grep -oE '[0-9]{4}' | head -1 || true)
    fi
    
    # Try table format: | **Ano** | 2016 |
    if [ -z "$year" ]; then
        year=$(grep -iE '\| \*\*(Year|Ano)\*\* \|' "$file" 2>/dev/null | grep -oE '[0-9]{4}' | head -1 || true)
    fi
    
    # Fallback: any line with Year/Ano followed by 4-digit number
    if [ -z "$year" ]; then
        year=$(grep -iE '(Year|Ano)[^0-9]*[0-9]{4}' "$file" 2>/dev/null | grep -oE '[0-9]{4}' | head -1 || true)
    fi
    
    echo "${year:-N/A}"
}

# Extract director from markdown file
extract_director() {
    local file="$1"
    local director=""
    
    # Try YAML frontmatter: director: "..."
    director=$(grep -m1 '^director:' "$file" 2>/dev/null | sed 's/^director:[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//' || true)
    
    # Try list format with colon inside bold: - **Director:** Frank Darabont
    if [ -z "$director" ]; then
        director=$(grep -iE '[-*] \*\*(Director|Diretor|Diretores?):\*\*' "$file" 2>/dev/null | sed 's/.*\*\*[^*]*\*\*[[:space:]]*//' | head -1 || true)
    fi
    
    # Try table format: | **Diretores** | Gastón Duprat, Mariano Cohn |
    if [ -z "$director" ]; then
        director=$(grep -iE '\| \*\*(Director|Diretor|Diretores?)\*\* \|' "$file" 2>/dev/null | awk -F'|' '{print $3}' | xargs | head -1 || true)
    fi
    
    # Try inline bold pattern with colon outside: **Director:** or **Diretor:**
    if [ -z "$director" ]; then
        director=$(grep -iE '\*\*(Director|Diretor|Diretores?)\*\*:' "$file" 2>/dev/null | sed 's/.*\*\*[^*]*\*\*:[[:space:]]*//' | head -1 || true)
    fi
    
    # Clean up and truncate
    director=$(echo "$director" | xargs | cut -c1-50)
    echo "${director:-Unknown}"
}

# Extract genres from markdown file
extract_genres() {
    local file="$1"
    local genres=""
    
    # Try **Genres:** or **Gêneros:** pattern
    genres=$(grep -iE '\*\*(Genres?|Gêneros?)\*\*:' "$file" 2>/dev/null | sed 's/.*\*\*[^*]*\*\*:[[:space:]]*//' | head -1 || true)
    
    # Try section with backticks: `Comédia` `Drama` `Sátira`
    if [ -z "$genres" ]; then
        # Look for line with backtick-wrapped genres after Gêneros/Genres header
        local genre_line=$(grep -A1 -iE '^## (Gêneros?|Genres?)' "$file" 2>/dev/null | tail -1 || true)
        if echo "$genre_line" | grep -q '`'; then
            genres=$(echo "$genre_line" | sed 's/`/ /g' | xargs | sed 's/  */, /g' || true)
        fi
    fi
    
    # Try hashtag format: `#drama` `#crime`
    if [ -z "$genres" ]; then
        local tag_line=$(grep -A1 -iE '^## Genre' "$file" 2>/dev/null | tail -1 || true)
        if echo "$tag_line" | grep -q '#'; then
            genres=$(echo "$tag_line" | sed 's/`//g' | sed 's/#//g' | xargs | sed 's/  */, /g' || true)
        fi
    fi
    
    # Clean up
    genres=$(echo "$genres" | xargs | cut -c1-40)
    echo "${genres:-N/A}"
}

# Process a single directory and output movie data
process_directory() {
    local dir="$1"
    local status="$2"  # "To Watch" or "Watched"
    
    if [ ! -d "$dir" ]; then
        return
    fi
    
    # Find all markdown files
    for file in "$dir"/*.md; do
        [ -f "$file" ] || continue
        
        local filename=$(basename "$file")
        local title=$(extract_title "$file")
        local year=$(extract_year "$file")
        local director=$(extract_director "$file")
        local genres=$(extract_genres "$file")
        local sort_key=$(strip_article "$title" | tr '[:upper:]' '[:lower:]')
        
        if [ -z "$title" ]; then
            log_warning "Skipping $filename - could not extract title"
            continue
        fi
        
        # Output: sort_key|title|year|director|genres|filepath
        echo "${sort_key}|${title}|${year}|${director}|${genres}|${status}/${filename}"
    done
}

# Generate INDEX.md
generate_index() {
    local output_file="$REPO_DIR/INDEX.md"
    local current_date
    current_date=$(date +%Y-%m-%d)
    
    log_info "Generating INDEX.md..."
    
    # Collect all movies
    local to_watch_data=""
    local watched_data=""
    
    if [ -d "$REPO_DIR/to-watch" ]; then
        to_watch_data=$(process_directory "$REPO_DIR/to-watch" "to-watch" | sort -t'|' -k1,1)
    fi
    
    if [ -d "$REPO_DIR/watched" ]; then
        watched_data=$(process_directory "$REPO_DIR/watched" "watched" | sort -t'|' -k1,1)
    fi
    
    # Count movies
    local to_watch_count=0
    local watched_count=0
    
    if [ -n "$to_watch_data" ]; then
        to_watch_count=$(echo "$to_watch_data" | wc -l)
    fi
    
    if [ -n "$watched_data" ]; then
        watched_count=$(echo "$watched_data" | wc -l)
    fi
    
    local total_count=$((to_watch_count + watched_count))
    
    # Generate the index file
    cat > "$output_file" << EOF
# 🎬 Movies Index

> Auto-generated index of all movies in the catalog.  
> Last updated: ${current_date}

## Summary

| Status | Count |
|--------|-------|
| 📋 To Watch | ${to_watch_count} |
| ✅ Watched | ${watched_count} |
| **Total** | **${total_count}** |

---

## 📋 To Watch

EOF
    
    if [ -z "$to_watch_data" ]; then
        echo "_No movies in the watchlist yet._" >> "$output_file"
    else
        cat >> "$output_file" << 'EOF'
| Title | Year | Director | Genres |
|-------|------|----------|--------|
EOF
        
        echo "$to_watch_data" | while IFS='|' read -r sort_key title year director genres filepath; do
            echo "| [${title}](${filepath}) | ${year} | ${director} | ${genres} |" >> "$output_file"
        done
    fi
    
    cat >> "$output_file" << EOF

---

## ✅ Watched

EOF
    
    if [ -z "$watched_data" ]; then
        echo "_No movies watched yet._" >> "$output_file"
    else
        cat >> "$output_file" << 'EOF'
| Title | Year | Director | Genres |
|-------|------|----------|--------|
EOF
        
        echo "$watched_data" | while IFS='|' read -r sort_key title year director genres filepath; do
            echo "| [${title}](${filepath}) | ${year} | ${director} | ${genres} |" >> "$output_file"
        done
    fi
    
    cat >> "$output_file" << EOF

---

*This index is automatically updated when movies are added to the catalog.*
EOF
    
    log_success "INDEX.md generated with ${total_count} movies"
}

# Main
main() {
    if [ ! -d "$REPO_DIR" ]; then
        log_error "Repository not found: $REPO_DIR"
        exit 1
    fi
    
    cd "$REPO_DIR"
    generate_index
}

main "$@"
