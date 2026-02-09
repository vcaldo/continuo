# Movies Skill

## Description

Enables the agent to add movies to the [vcaldo/movies](https://github.com/vcaldo/movies) catalog repository. When a user mentions a movie they want to track, the agent gathers information and creates a structured markdown entry.

## Trigger

Activate this skill when the user:
- Asks to add a movie to their watchlist/catalog
- Mentions wanting to watch a specific movie
- Requests movie information to be saved
- Uses phrases like "add [movie] to my movies", "save [movie]", "track [movie]"

## Workflow

### Step 1: Search for Movie Information

Use `web_search` to find comprehensive movie details:

```
web_search: "[Movie Title] movie [year if known] IMDb Rotten Tomatoes ratings director"
```

**Required information to gather:**
| Field | Description | Example |
|-------|-------------|---------|
| Title | Original movie title | "The Shawshank Redemption" |
| Year | Release year | 1994 |
| Director | Director name(s) | "Frank Darabont" |
| Runtime | Duration in minutes | 142 |
| Synopsis | Brief plot summary (2-3 sentences) | "Two imprisoned men bond..." |
| IMDb | Rating out of 10 | "9.3/10" |
| Rotten Tomatoes | Critic score percentage | "91%" |
| Metacritic | Score out of 100 | "82/100" |
| Letterboxd | Rating out of 5 | "4.5/5" |
| Genres | Comma-separated genres | "Drama, Crime" |
| Streaming | Where to watch | "Netflix, Amazon Prime" |
| Poster | High-quality image URL | "https://..." |

> **Tip:** For poster URLs, TMDB, IMDb, and Letterboxd have high-quality images. Prefer HTTPS URLs.

### Step 2: Create the Movie Entry

Use the `create-and-commit.sh` script with environment variables:

```bash
cd /path/to/continuo/skills_scripts/movies

MOVIE_TITLE="The Shawshank Redemption" \
MOVIE_YEAR="1994" \
MOVIE_DIRECTOR="Frank Darabont" \
MOVIE_RUNTIME="142" \
MOVIE_SYNOPSIS="Two imprisoned men bond over a number of years, finding solace and eventual redemption through acts of common decency." \
MOVIE_IMDB="9.3/10" \
MOVIE_RT="91%" \
MOVIE_METACRITIC="82/100" \
MOVIE_LETTERBOXD="4.5/5" \
MOVIE_GENRES="Drama, Crime" \
MOVIE_STREAMING="Available on Netflix" \
MOVIE_POSTER="https://example.com/shawshank-poster.jpg" \
./create-and-commit.sh
```

The script will:
1. Clone/update the repository to `/tmp/movies`
2. Create the markdown file in `/to-watch/`
3. Commit and push directly to main branch

### Step 3: Confirm to User

Report success with the movie details:

```
✅ Added **The Shawshank Redemption (1994)** to your movies catalog!

📊 Ratings: IMDb 9.3 | RT 91% | Metacritic 82
🎬 Director: Frank Darabont
⏱️ Runtime: 142 min
📺 Streaming: Netflix

🔗 https://github.com/vcaldo/movies/blob/main/to-watch/the-shawshank-redemption-1994.md
```

## Script Reference

### create-and-commit.sh (Recommended)

Full automation script that creates, commits, and pushes in one step.

**Environment Variables:**
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| MOVIE_TITLE | ✅ Yes | - | Movie title |
| MOVIE_YEAR | No | TBD | Release year |
| MOVIE_DIRECTOR | No | Unknown | Director name(s) |
| MOVIE_RUNTIME | No | 0 | Runtime in minutes |
| MOVIE_SYNOPSIS | No | No synopsis available. | Plot summary |
| MOVIE_IMDB | No | N/A | IMDb rating |
| MOVIE_RT | No | N/A | Rotten Tomatoes score |
| MOVIE_METACRITIC | No | N/A | Metacritic score |
| MOVIE_LETTERBOXD | No | N/A | Letterboxd rating |
| MOVIE_GENRES | No | Unknown | Genres |
| MOVIE_STREAMING | No | Check streaming services | Where to watch |
| MOVIE_POSTER | No | (empty) | Poster URL |
| DRY_RUN | No | 0 | Set to 1 to preview without committing |
| FORCE | No | 0 | Set to 1 to overwrite existing entries |

### add-movie.sh (Template Only)

Creates a template file without committing. Useful for manual editing.

```bash
./add-movie.sh "Movie Name" [year]
```

## Error Handling

### Common Issues

| Error | Cause | Solution |
|-------|-------|----------|
| "MOVIE_TITLE is required" | Missing title | Always set MOVIE_TITLE |
| "Movie already exists" | Duplicate entry | Use FORCE=1 to overwrite |
| "Failed to push" | Conflict with remote | Script auto-retries with rebase |
| "Failed to clone" | Network/auth issue | Check internet connection |

### Validation

The scripts validate:
- Title is not empty
- Year is 4 digits (if provided)
- Runtime is numeric (if provided)

## File Format

Movies are saved to `/to-watch/filename.md` with this structure:

**Filename format:** `movie-title-year.md` (lowercase, hyphenated)

**Example:** `the-shawshank-redemption-1994.md`

```markdown
---
title: "The Shawshank Redemption"
year: 1994
director: "Frank Darabont"
runtime: 142 min
---

# The Shawshank Redemption (1994)

**Director:** Frank Darabont  
**Runtime:** 142 minutes

## Synopsis

Two imprisoned men bond over a number of years...

## Ratings

| Source | Rating |
|--------|--------|
| IMDb | 9.3/10 |
| Rotten Tomatoes | 91% |
| Metacritic | 82/100 |
| Letterboxd | 4.5/5 |

## Details

**Genres:** Drama, Crime  
**Streaming:** Available on Netflix

## Poster

![The Shawshank Redemption Poster](https://example.com/poster.jpg)

---

*Added to catalog: 2024-01-15*
```

## Best Practices

1. **Always search for current information** - Ratings and streaming availability change
2. **Use high-quality poster images** - Prefer TMDB, IMDb, or Letterboxd sources
3. **Include all available ratings** - Some may not exist for all films (use N/A)
4. **Write concise synopses** - 2-3 sentences, no major spoilers
5. **Push directly to main** - No pull requests required for this workflow
6. **Use DRY_RUN=1 first** - When testing or unsure

## Tools Used

| Tool | Purpose |
|------|---------|
| `web_search` | Find movie information and ratings |
| `exec` | Run shell scripts and git commands |
| `write` | Alternative: create markdown files directly |

## Example Interactions

**User:** "Add Inception to my movies"

**Agent:**
1. `web_search`: "Inception 2010 movie IMDb Rotten Tomatoes ratings director Christopher Nolan"
2. Gather details: Year 2010, Director Nolan, Runtime 148 min, etc.
3. Run `create-and-commit.sh` with environment variables
4. Reply: "✅ Added **Inception (2010)** to your movies catalog! 🎬"

**User:** "I want to watch The Godfather, save it"

**Agent:**
1. `web_search`: "The Godfather 1972 movie IMDb Rotten Tomatoes Metacritic ratings"
2. Gather all details including poster URL
3. Run script with MOVIE_TITLE="The Godfather" MOVIE_YEAR="1972" ...
4. Reply with confirmation and link

**User:** "Add the new Dune movie"

**Agent:**
1. `web_search`: "Dune 2021 Denis Villeneuve movie ratings IMDb"
2. Clarify if needed: "Do you mean Dune (2021) or Dune: Part Two (2024)?"
3. Proceed with confirmed movie
