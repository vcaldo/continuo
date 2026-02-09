#!/bin/bash

# add-movie.sh - Add a movie to the catalog
# Usage: ./add-movie.sh "Movie Name" [year] [director] [runtime] [imdb] [rt] [metacritic] [letterboxd]

set -e

MOVIE_NAME="$1"
YEAR="${2:-YYYY}"
DIRECTOR="${3:-Unknown}"
RUNTIME="${4:-0}"
IMDB="${5:-N/A}"
RT="${6:-N/A}"
METACRITIC="${7:-N/A}"
LETTERBOXD="${8:-N/A}"

if [ -z "$MOVIE_NAME" ]; then
    echo "Usage: $0 \"Movie Name\" [year] [director] [runtime] [imdb] [rt] [metacritic] [letterboxd]"
    echo ""
    echo "Example: $0 \"The Matrix\" 1999 \"Wachowski Sisters\" 136 \"8.7/10\" \"88%\" \"73/100\" \"4.2/5\""
    echo ""
    echo "Or just provide movie name and fill in template manually:"
    echo "  $0 \"The Matrix\""
    exit 1
fi

# Clone repo if not present
REPO_DIR="/tmp/movies"
if [ ! -d "$REPO_DIR" ]; then
    echo "📦 Cloning repository..."
    cd /tmp
    git clone https://github.com/vcaldo/movies.git
fi

cd "$REPO_DIR"

# Pull latest changes
echo "🔄 Pulling latest changes..."
git pull origin main

# Create to-watch directory if it doesn't exist
mkdir -p to-watch

# Generate filename (lowercase, replace spaces with hyphens)
FILENAME=$(echo "$MOVIE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')
if [ "$YEAR" != "YYYY" ]; then
    FILENAME="${FILENAME}-${YEAR}"
fi
FILEPATH="to-watch/${FILENAME}.md"

echo "📝 Creating movie file: $FILEPATH"

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Create markdown file
cat > "$FILEPATH" << EOF
---
title: "$MOVIE_NAME"
year: $YEAR
director: "$DIRECTOR"
runtime: $RUNTIME min
---

# $MOVIE_NAME ($YEAR)

**Director:** $DIRECTOR  
**Runtime:** $RUNTIME minutes

## Synopsis

[Add plot summary here]

## Ratings

- **IMDb:** $IMDB
- **Rotten Tomatoes:** $RT
- **Metacritic:** $METACRITIC
- **Letterboxd:** $LETTERBOXD

## Details

**Genres:** [Add genres here]  
**Streaming:** [Add streaming availability here]

## Poster

![Poster](add-poster-url-here)

---

*Added to catalog: $CURRENT_DATE*
EOF

echo "✅ Created $FILEPATH"
echo ""
echo "📋 Next steps:"
echo "  1. Edit the file to add missing information (synopsis, genres, streaming, poster)"
echo "  2. Or use the update-movie.sh script (if available)"
echo "  3. Commit and push:"
echo "     git add $FILEPATH"
echo "     git commit -m 'Add $MOVIE_NAME ($YEAR)'"
echo "     git push origin main"
echo ""
echo "🎬 Movie template created! Fill in the details and commit."
