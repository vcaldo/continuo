# Movies Skill

## Description

Add movies to the vcaldo/movies catalog repository. This skill helps you discover movie information and catalog it in markdown format for tracking what to watch.

## Repository

https://github.com/vcaldo/movies

## Usage

When a user mentions a movie they want to add or track:

1. **Search for movie information** using web search
2. **Gather required details:**
   - Title (original title)
   - Year of release
   - Director(s)
   - Runtime (in minutes)
   - Synopsis/plot summary
   - Ratings:
     - IMDb (e.g., 7.8/10)
     - Rotten Tomatoes (e.g., 92%)
     - Metacritic (e.g., 85/100)
     - Letterboxd (e.g., 4.1/5)
   - Poster URL (high quality)
   - Genres (e.g., Drama, Thriller)
   - Streaming availability (where to watch)

3. **Create the markdown file** either by:
   - Running `./add-movie.sh "Movie Name"` from the skill directory, OR
   - Manually creating the file using the template below

4. **Commit directly to main branch** (NO pull requests)

5. **Report back** to the user confirming the movie was added

## File Template

Save movies to `/to-watch/` folder with filename format: `movie-title-year.md`

```markdown
---
title: "Movie Title"
year: YYYY
director: "Director Name"
runtime: XXX min
---

# Movie Title (YYYY)

**Director:** Director Name  
**Runtime:** XXX minutes

## Synopsis

[Brief plot summary]

## Ratings

- **IMDb:** X.X/10
- **Rotten Tomatoes:** XX%
- **Metacritic:** XX/100
- **Letterboxd:** X.X/5

## Details

**Genres:** Genre1, Genre2, Genre3  
**Streaming:** Available on [Platform] or [Platform]

## Poster

![Poster](poster-url-here)

---

*Added to catalog: YYYY-MM-DD*
```

## Workflow

```bash
# Clone repo if not already present
cd /tmp
git clone https://github.com/vcaldo/movies.git
cd movies

# Search for movie info (use web_search tool)
# Populate the markdown file with real data

# Create the file in to-watch folder
# Use the add-movie.sh script or create manually

# Commit and push directly to main
git add to-watch/*.md
git commit -m "Add [Movie Title] (YYYY)"
git push origin main
```

## Notes

- Always search for accurate, up-to-date information
- Use high-quality poster images
- Include all available ratings (some may not be available for all films)
- Streaming availability changes - note current status
- Commit messages should be descriptive: "Add [Movie Title] (Year)"
- **NO pull requests** - push directly to main branch
- Clean up /tmp after pushing

## Example User Interaction

**User:** "Add The Shawshank Redemption"

**Agent Actions:**
1. Search web for "The Shawshank Redemption movie info ratings"
2. Gather all details (1994, Frank Darabont, 142 min, etc.)
3. Run `./add-movie.sh "The Shawshank Redemption"` or create file manually
4. Git commit and push to main
5. Reply: "✅ Added **The Shawshank Redemption (1994)** to your movies catalog!"

## Tools Used

- `web_search` - Find movie information
- `exec` - Run git commands and shell script
- `write` - Create markdown files if not using script
