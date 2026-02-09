#!/bin/bash

# create-and-commit.sh - Create movie file with full details and commit
# This script is designed to be called by the agent with complete information
#
# Usage: Set environment variables and run the script:
#   MOVIE_TITLE="The Matrix" MOVIE_YEAR="1999" ./create-and-commit.sh
#
# Required: MOVIE_TITLE
# Optional: MOVIE_YEAR, MOVIE_DIRECTOR, MOVIE_RUNTIME, MOVIE_SYNOPSIS,
#           MOVIE_IMDB, MOVIE_RT, MOVIE_METACRITIC, MOVIE_LETTERBOXD,
#           MOVIE_GENRES, MOVIE_STREAMING, MOVIE_POSTER

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository configuration
REPO_URL="https://github.com/vcaldo/movies.git"
REPO_DIR="/tmp/movies"
TARGET_DIR="to-watch"

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}" >&2; }

# Print usage
usage() {
    cat << EOF
Usage: MOVIE_TITLE="Title" [OPTIONS] $0

Creates a movie entry in the vcaldo/movies catalog and commits it directly to main.

Required Environment Variables:
  MOVIE_TITLE       Movie title (required)

Optional Environment Variables:
  MOVIE_YEAR        Release year (default: TBD)
  MOVIE_DIRECTOR    Director name(s)
  MOVIE_RUNTIME     Runtime in minutes
  MOVIE_SYNOPSIS    Plot summary
  MOVIE_IMDB        IMDb rating (e.g., "8.7/10")
  MOVIE_RT          Rotten Tomatoes score (e.g., "88%")
  MOVIE_METACRITIC  Metacritic score (e.g., "73/100")
  MOVIE_LETTERBOXD  Letterboxd rating (e.g., "4.2/5")
  MOVIE_GENRES      Genres (e.g., "Sci-Fi, Action, Drama")
  MOVIE_STREAMING   Where to watch (e.g., "Netflix, Amazon Prime")
  MOVIE_POSTER      URL to poster image
  
Flags:
  DRY_RUN=1         Preview without committing
  FORCE=1           Overwrite existing entry

Example:
  MOVIE_TITLE="The Matrix" \\
  MOVIE_YEAR="1999" \\
  MOVIE_DIRECTOR="Lana Wachowski, Lilly Wachowski" \\
  MOVIE_RUNTIME="136" \\
  MOVIE_SYNOPSIS="A computer hacker learns about the true nature of reality." \\
  MOVIE_IMDB="8.7/10" \\
  MOVIE_RT="88%" \\
  MOVIE_METACRITIC="73/100" \\
  MOVIE_LETTERBOXD="4.2/5" \\
  MOVIE_GENRES="Sci-Fi, Action" \\
  MOVIE_STREAMING="Available on Netflix, Amazon Prime" \\
  MOVIE_POSTER="https://example.com/matrix-poster.jpg" \\
  ./create-and-commit.sh
EOF
}

# Validate required inputs
validate_inputs() {
    if [ -z "${MOVIE_TITLE:-}" ]; then
        log_error "MOVIE_TITLE is required"
        echo ""
        usage
        exit 1
    fi
    
    # Validate year format if provided
    if [ -n "${MOVIE_YEAR:-}" ] && [ "$MOVIE_YEAR" != "TBD" ]; then
        if ! [[ "$MOVIE_YEAR" =~ ^[0-9]{4}$ ]]; then
            log_error "MOVIE_YEAR must be a 4-digit year (e.g., 1999)"
            exit 1
        fi
    fi
    
    # Validate runtime is numeric if provided
    if [ -n "${MOVIE_RUNTIME:-}" ] && [ "$MOVIE_RUNTIME" != "0" ]; then
        if ! [[ "$MOVIE_RUNTIME" =~ ^[0-9]+$ ]]; then
            log_error "MOVIE_RUNTIME must be a number (minutes)"
            exit 1
        fi
    fi
}

# Generate a safe filename from title and year
generate_filename() {
    local title="$1"
    local year="${2:-}"
    
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    local filename
    filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
    
    if [ -n "$year" ] && [ "$year" != "TBD" ]; then
        filename="${filename}-${year}"
    fi
    
    echo "${filename}.md"
}

# Setup repository (clone or pull)
setup_repo() {
    if [ ! -d "$REPO_DIR" ]; then
        log_info "Cloning repository..."
        if ! git clone "$REPO_URL" "$REPO_DIR" 2>&1; then
            log_error "Failed to clone repository"
            exit 1
        fi
        log_success "Repository cloned"
    else
        log_info "Updating repository..."
        cd "$REPO_DIR"
        if ! git fetch origin 2>&1; then
            log_warning "Failed to fetch, trying with existing state"
        fi
        if ! git reset --hard origin/main 2>&1; then
            log_error "Failed to reset to main branch"
            exit 1
        fi
        log_success "Repository updated"
    fi
    
    cd "$REPO_DIR"
    mkdir -p "$TARGET_DIR"
}

# Validate poster URL by checking HTTP status
validate_poster_url() {
    if [ -n "${MOVIE_POSTER:-}" ]; then
        log_info "Validating poster URL..."
        local status
        status=$(curl -sI "$MOVIE_POSTER" -o /dev/null -w '%{http_code}' --max-time 5 2>/dev/null || echo "000")
        
        if [ "$status" = "200" ]; then
            log_success "Poster URL valid (HTTP $status)"
        else
            log_warning "Poster URL returned HTTP $status - clearing poster"
            MOVIE_POSTER=""
        fi
    fi
}

# Check if movie already exists
check_existing() {
    local filename="$1"
    local filepath="${TARGET_DIR}/${filename}"
    
    if [ -f "$filepath" ]; then
        if [ "${FORCE:-}" = "1" ]; then
            log_warning "File exists, will overwrite: $filepath"
            return 0
        else
            log_error "Movie already exists: $filepath"
            log_info "Use FORCE=1 to overwrite"
            exit 1
        fi
    fi
}

# Create the movie markdown file
create_movie_file() {
    local filepath="$1"
    local current_date
    current_date=$(date +%Y-%m-%d)
    
    cat > "$filepath" << EOF
---
title: "${MOVIE_TITLE}"
year: ${MOVIE_YEAR}
director: "${MOVIE_DIRECTOR}"
runtime: ${MOVIE_RUNTIME} min
---

# ${MOVIE_TITLE} (${MOVIE_YEAR})

**Director:** ${MOVIE_DIRECTOR}  
**Runtime:** ${MOVIE_RUNTIME} minutes

## Synopsis

${MOVIE_SYNOPSIS}

## Ratings

| Source | Rating |
|--------|--------|
| IMDb | ${MOVIE_IMDB} |
| Rotten Tomatoes | ${MOVIE_RT} |
| Metacritic | ${MOVIE_METACRITIC} |
| Letterboxd | ${MOVIE_LETTERBOXD} |

## Details

**Genres:** ${MOVIE_GENRES}  
**Streaming:** ${MOVIE_STREAMING}

## Poster

![${MOVIE_TITLE} Poster](${MOVIE_POSTER})

---

*Added to catalog: ${current_date}*
EOF
}

# Commit and push changes
commit_and_push() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    
    # Configure git user if not set
    if [ -z "$(git config user.email)" ]; then
        git config user.email "openclaw@local"
        git config user.name "OpenClaw Agent"
    fi
    
    log_info "Staging changes..."
    git add "$filepath"
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_warning "No changes to commit (file unchanged)"
        return 0
    fi
    
    local commit_msg="Add ${MOVIE_TITLE} (${MOVIE_YEAR})"
    
    log_info "Committing: $commit_msg"
    git commit -m "$commit_msg"
    
    log_info "Pushing to origin/main..."
    if ! git push origin main 2>&1; then
        log_error "Failed to push. Trying to pull and rebase..."
        if git pull --rebase origin main && git push origin main; then
            log_success "Push succeeded after rebase"
        else
            log_error "Push failed. You may need to resolve conflicts manually."
            log_info "Repository location: $REPO_DIR"
            exit 1
        fi
    fi
    
    log_success "Pushed to repository"
}

# Main execution
main() {
    log_info "Starting movie catalog update..."
    echo ""
    
    # Set defaults for missing values
    MOVIE_YEAR="${MOVIE_YEAR:-TBD}"
    MOVIE_DIRECTOR="${MOVIE_DIRECTOR:-Unknown}"
    MOVIE_RUNTIME="${MOVIE_RUNTIME:-0}"
    MOVIE_SYNOPSIS="${MOVIE_SYNOPSIS:-No synopsis available.}"
    MOVIE_IMDB="${MOVIE_IMDB:-N/A}"
    MOVIE_RT="${MOVIE_RT:-N/A}"
    MOVIE_METACRITIC="${MOVIE_METACRITIC:-N/A}"
    MOVIE_LETTERBOXD="${MOVIE_LETTERBOXD:-N/A}"
    MOVIE_GENRES="${MOVIE_GENRES:-Unknown}"
    MOVIE_STREAMING="${MOVIE_STREAMING:-Check streaming services}"
    MOVIE_POSTER="${MOVIE_POSTER:-}"
    
    # Validate inputs
    validate_inputs
    
    # Validate poster URL
    validate_poster_url
    
    # Generate filename
    local filename
    filename=$(generate_filename "$MOVIE_TITLE" "$MOVIE_YEAR")
    local filepath="${TARGET_DIR}/${filename}"
    
    log_info "Movie: ${MOVIE_TITLE} (${MOVIE_YEAR})"
    log_info "File: ${filepath}"
    echo ""
    
    # Setup repository
    setup_repo
    
    # Check for existing file
    check_existing "$filename"
    
    # Create the file
    log_info "Creating movie entry..."
    create_movie_file "$filepath"
    log_success "Created ${filepath}"
    
    # Handle dry run
    if [ "${DRY_RUN:-}" = "1" ]; then
        echo ""
        log_warning "DRY RUN - File created but not committed"
        log_info "Preview file at: ${REPO_DIR}/${filepath}"
        echo ""
        echo "--- File Content ---"
        cat "$filepath"
        echo "--- End Content ---"
        exit 0
    fi
    
    # Commit and push
    commit_and_push "$filepath"
    
    echo ""
    log_success "🎬 Successfully added '${MOVIE_TITLE}' to the movies catalog!"
    echo ""
    echo -e "${BLUE}📎 View at:${NC} https://github.com/vcaldo/movies/blob/main/${filepath}"
}

# Run main
main "$@"
