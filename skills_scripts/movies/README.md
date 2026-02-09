# Movies Skill

This skill enables adding movies to the [vcaldo/movies](https://github.com/vcaldo/movies) catalog repository.

## Files

- **SKILL.md** - Main skill documentation for the agent
- **add-movie.sh** - Basic script to create movie template
- **create-and-commit.sh** - Advanced script that creates, commits, and pushes with full details

## Quick Start

### For the Agent

When a user mentions a movie to add:

1. Use `web_search` to find movie information
2. Gather all details (title, year, director, runtime, synopsis, ratings, genres, streaming, poster)
3. Either:
   - Call `create-and-commit.sh` with environment variables, OR
   - Create the markdown file manually using the template in SKILL.md
4. Commit and push directly to main branch (no PRs)
5. Confirm to user

### Manual Usage

```bash
# Basic template creation
./add-movie.sh "Movie Name"

# Full creation with all details
MOVIE_TITLE="The Matrix" \
MOVIE_YEAR="1999" \
MOVIE_DIRECTOR="Wachowski Sisters" \
MOVIE_RUNTIME="136" \
MOVIE_SYNOPSIS="A hacker discovers reality is a simulation..." \
MOVIE_IMDB="8.7/10" \
MOVIE_RT="88%" \
MOVIE_METACRITIC="73/100" \
MOVIE_LETTERBOXD="4.2/5" \
MOVIE_GENRES="Sci-Fi, Action" \
MOVIE_STREAMING="Available on Netflix, Amazon Prime" \
MOVIE_POSTER="https://image.url/poster.jpg" \
./create-and-commit.sh
```

## Workflow

1. **Search**: Find movie information via web search
2. **Create**: Generate markdown file in `/to-watch/` folder
3. **Commit**: Push directly to main branch
4. **Confirm**: Report back to user with success message

## Notes

- Repository is cloned to `/tmp/movies` for operations
- All movies go in the `to-watch/` subfolder
- Filename format: `movie-title-year.md` (lowercase, hyphenated)
- Always commit directly to main (no pull requests)
- Clean up `/tmp/movies` after operations if needed
