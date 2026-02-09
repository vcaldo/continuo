#!/bin/bash

# add-movie.sh - Add a movie template to the catalog
# This creates a template file that can be filled in manually or by the agent
#
# Usage: ./add-movie.sh "Movie Name" [year]
# Example: ./add-movie.sh "The Matrix" 1999

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
Usage: $0 "Movie Name" [year]

Creates a movie template in the vcaldo/movies catalog repository.
The template will have placeholder values that should be filled in.

Arguments:
  Movie Name    Required. The title of the movie.
  year          Optional. The release year (4 digits).

Examples:
  $0 "The Matrix"
  $0 "The Matrix" 1999
  $0 "Inception" 2010

Options:
  -h, --help    Show this help message

For full movie entries with all details, use create-and-commit.sh instead:
  MOVIE_TITLE="The Matrix" MOVIE_YEAR="1999" ./create-and-commit.sh

EOF
}

# Show help if requested
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

# Validate arguments
MOVIE_NAME="${1:-}"
YEAR="${2:-YYYY}"

if [ -z "$MOVIE_NAME" ]; then
    log_error "Movie name is required"
    echo ""
    usage
    exit 1
fi

# Validate year format if provided
if [ "$YEAR" != "YYYY" ]; then
    if ! [[ "$YEAR" =~ ^[0-9]{4}$ ]]; then
        log_error "Year must be a 4-digit number (e.g., 1999)"
        exit 1
    fi
fi

# Generate safe filename
generate_filename() {
    local title="$1"
    local year="${2:-}"
    
    local filename
    filename=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
    
    if [ -n "$year" ] && [ "$year" != "YYYY" ]; then
        filename="${filename}-${year}"
    fi
    
    echo "${filename}.md"
}

# Clone or update repository
setup_repo() {
    if [ ! -d "$REPO_DIR" ]; then
        log_info "Cloning repository..."
        if ! git clone "$REPO_URL" "$REPO_DIR" 2>&1; then
            log_error "Failed to clone repository"
            exit 1
        fi
        log_success "Repository cloned to $REPO_DIR"
    else
        log_info "Updating repository..."
        cd "$REPO_DIR"
        if git pull origin main 2>&1; then
            log_success "Repository updated"
        else
            log_warning "Could not pull latest changes, continuing with current state"
        fi
    fi
    
    cd "$REPO_DIR"
    mkdir -p "$TARGET_DIR"
}

# Main execution
log_info "Creating movie template for: ${MOVIE_NAME}"
echo ""

# Setup repository
setup_repo

# Generate filename and path
FILENAME=$(generate_filename "$MOVIE_NAME" "$YEAR")
FILEPATH="${TARGET_DIR}/${FILENAME}"

# Check if file exists
if [ -f "$FILEPATH" ]; then
    log_warning "File already exists: $FILEPATH"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted. File not modified."
        exit 0
    fi
fi

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Create markdown template
cat > "$FILEPATH" << EOF
---
title: "${MOVIE_NAME}"
year: ${YEAR}
director: "TBD"
runtime: 0 min
---

# ${MOVIE_NAME} (${YEAR})

**Director:** TBD  
**Runtime:** TBD minutes

## Synopsis

<!-- Add plot summary here -->

## Ratings

| Source | Rating |
|--------|--------|
| IMDb | N/A |
| Rotten Tomatoes | N/A |
| Metacritic | N/A |
| Letterboxd | N/A |

## Details

**Genres:** TBD  
**Streaming:** TBD

## Poster

<!-- Add poster URL: ![Poster](url) -->

---

*Added to catalog: ${CURRENT_DATE}*
*Template created - fill in the details above*
EOF

log_success "Created template: $FILEPATH"
echo ""

# Show file location
echo -e "${BLUE}📁 File location:${NC} ${REPO_DIR}/${FILEPATH}"
echo ""

# Show next steps
echo -e "${YELLOW}📋 Next steps:${NC}"
echo "  1. Fill in the template with movie details:"
echo "     - Director, runtime, synopsis"
echo "     - Ratings from IMDb, Rotten Tomatoes, Metacritic, Letterboxd"
echo "     - Genres and streaming availability"
echo "     - Poster URL"
echo ""
echo "  2. Commit and push:"
echo "     cd $REPO_DIR"
echo "     git add $FILEPATH"
echo "     git commit -m 'Add ${MOVIE_NAME} (${YEAR})'"
echo "     git push origin main"
echo ""
echo -e "${GREEN}💡 Tip:${NC} Use create-and-commit.sh for a one-step process with all details."
