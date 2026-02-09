#!/bin/bash

# create-and-commit.sh - Create movie file with full details and commit
# This script is designed to be called by the agent with complete information

set -e

# Read parameters from environment variables or arguments
MOVIE_TITLE="${MOVIE_TITLE:-$1}"
MOVIE_YEAR="${MOVIE_YEAR:-$2}"
MOVIE_DIRECTOR="${MOVIE_DIRECTOR:-$3}"
MOVIE_RUNTIME="${MOVIE_RUNTIME:-$4}"
MOVIE_SYNOPSIS="${MOVIE_SYNOPSIS:-$5}"
MOVIE_IMDB="${MOVIE_IMDB:-$6}"
MOVIE_RT="${MOVIE_RT:-$7}"
MOVIE_METACRITIC="${MOVIE_METACRITIC:-$8}"
MOVIE_LETTERBOXD="${MOVIE_LETTERBOXD:-$9}"
MOVIE_GENRES="${MOVIE_GENRES:-${10}}"
MOVIE_STREAMING="${MOVIE_STREAMING:-${11}}"
MOVIE_POSTER="${MOVIE_POSTER:-${12}}"

if [ -z "$MOVIE_TITLE" ]; then
    echo "Error: Movie title is required"
    echo ""
    echo "Usage: Set environment variables or pass arguments:"
    echo "  MOVIE_TITLE=\"The Matrix\" MOVIE_YEAR=\"1999\" ... $0"
    echo ""
    echo "Required: MOVIE_TITLE"
    echo "Optional: MOVIE_YEAR, MOVIE_DIRECTOR, MOVIE_RUNTIME, MOVIE_SYNOPSIS,"
    echo "          MOVIE_IMDB, MOVIE_RT, MOVIE_METACRITIC, MOVIE_LETTERBOXD,"
    echo "          MOVIE_GENRES, MOVIE_STREAMING, MOVIE_POSTER"
    exit 1
fi

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
MOVIE_POSTER="${MOVIE_POSTER:-No poster available}"

# Clone/update repo
REPO_DIR="/tmp/movies"
if [ ! -d "$REPO_DIR" ]; then
    echo "📦 Cloning repository..."
    cd /tmp
    git clone https://github.com/vcaldo/movies.git
else
    echo "🔄 Updating repository..."
    cd "$REPO_DIR"
    git pull origin main
fi

cd "$REPO_DIR"
mkdir -p to-watch

# Generate filename
FILENAME=$(echo "$MOVIE_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')
if [ "$MOVIE_YEAR" != "TBD" ]; then
    FILENAME="${FILENAME}-${MOVIE_YEAR}"
fi
FILEPATH="to-watch/${FILENAME}.md"

CURRENT_DATE=$(date +%Y-%m-%d)

# Create the markdown file
cat > "$FILEPATH" << EOF
---
title: "$MOVIE_TITLE"
year: $MOVIE_YEAR
director: "$MOVIE_DIRECTOR"
runtime: $MOVIE_RUNTIME min
---

# $MOVIE_TITLE ($MOVIE_YEAR)

**Director:** $MOVIE_DIRECTOR  
**Runtime:** $MOVIE_RUNTIME minutes

## Synopsis

$MOVIE_SYNOPSIS

## Ratings

- **IMDb:** $MOVIE_IMDB
- **Rotten Tomatoes:** $MOVIE_RT
- **Metacritic:** $MOVIE_METACRITIC
- **Letterboxd:** $MOVIE_LETTERBOXD

## Details

**Genres:** $MOVIE_GENRES  
**Streaming:** $MOVIE_STREAMING

## Poster

![Poster]($MOVIE_POSTER)

---

*Added to catalog: $CURRENT_DATE*
EOF

echo "✅ Created $FILEPATH"

# Commit and push
echo "📤 Committing and pushing to repository..."
git add "$FILEPATH"
git commit -m "Add $MOVIE_TITLE ($MOVIE_YEAR)"
git push origin main

echo ""
echo "🎉 Successfully added $MOVIE_TITLE to the movies catalog!"
echo "🔗 https://github.com/vcaldo/movies/blob/main/$FILEPATH"
