# 🎬 Movies Skill

Add movies to the [vcaldo/movies](https://github.com/vcaldo/movies) catalog repository.

## Overview

This skill enables an AI agent to catalog movies when users mention them. It searches for movie information (title, director, ratings, synopsis, poster) and creates structured markdown entries in the movies repository.

## Files

| File | Description |
|------|-------------|
| `SKILL.md` | Agent instructions - how to use this skill |
| `create-and-commit.sh` | Main script - creates entry and pushes to repo |
| `add-movie.sh` | Template script - creates template for manual editing |
| `update-index.sh` | Generates INDEX.md from all movies (called automatically) |
| `README.md` | This file - developer documentation |

## Quick Start

### For the Agent

See `SKILL.md` for complete instructions. The basic flow is:

1. User mentions a movie → Agent activates skill
2. Search for movie information with `web_search`
3. Run `create-and-commit.sh` with gathered data
4. Confirm to user with movie details

### For Developers

```bash
# Create a movie entry with full details
MOVIE_TITLE="The Matrix" \
MOVIE_YEAR="1999" \
MOVIE_DIRECTOR="Lana Wachowski, Lilly Wachowski" \
MOVIE_RUNTIME="136" \
MOVIE_SYNOPSIS="A computer hacker discovers reality is a simulation." \
MOVIE_IMDB="8.7/10" \
MOVIE_RT="88%" \
MOVIE_METACRITIC="73/100" \
MOVIE_LETTERBOXD="4.2/5" \
MOVIE_GENRES="Sci-Fi, Action" \
MOVIE_STREAMING="Netflix, Amazon Prime" \
MOVIE_POSTER="https://example.com/matrix.jpg" \
./create-and-commit.sh

# Or just create a template to fill manually
./add-movie.sh "The Matrix" 1999
```

## Script Options

### create-and-commit.sh

| Option | Description |
|--------|-------------|
| `DRY_RUN=1` | Preview the file without committing |
| `FORCE=1` | Overwrite if movie already exists |

Example:
```bash
DRY_RUN=1 MOVIE_TITLE="Test" ./create-and-commit.sh
```

### add-movie.sh

```bash
./add-movie.sh "Movie Name" [year]
./add-movie.sh -h  # Show help
```

### update-index.sh

Generates INDEX.md with all movies from to-watch/ and watched/ directories.

```bash
./update-index.sh [REPO_DIR]
# REPO_DIR defaults to /tmp/movies
```

**Features:**
- Extracts title, year, director, and genres from each movie file
- Sorts alphabetically, ignoring articles (The, A, An, O, El, La...)
- Creates linked tables for easy navigation
- Called automatically by `create-and-commit.sh`

**Manual regeneration:**
```bash
./update-index.sh /tmp/movies
cd /tmp/movies && git add INDEX.md && git commit -m "chore: update index" && git push
```

## Output Format

Movies are saved to the repository at:
```
/to-watch/movie-title-year.md
```

Example: `/to-watch/the-matrix-1999.md`

The markdown includes YAML frontmatter and structured sections for synopsis, ratings (in table format), genres, streaming availability, and poster.

## Repository Structure

```
vcaldo/movies/
├── to-watch/           # Movies to watch
│   ├── movie-1.md
│   └── movie-2.md
├── watched/            # Movies already watched (future)
└── README.md
```

## Troubleshooting

### "Movie already exists"

The file already exists in the repository. Options:
- Use `FORCE=1` to overwrite
- Choose a different movie
- Manually edit the existing entry

### "Failed to push"

Usually caused by concurrent edits. The script automatically tries to rebase and retry. If it still fails:

```bash
cd /tmp/movies
git pull --rebase origin main
git push origin main
```

### "Failed to clone"

Check your network connection and GitHub access. The repository must be accessible at: https://github.com/vcaldo/movies

### Git user not configured

The script automatically sets a default git user (`openclaw@local`) if none is configured. To use your own:

```bash
git config --global user.email "your@email.com"
git config --global user.name "Your Name"
```

## Development

### Testing Changes

Use `DRY_RUN=1` to test without committing:

```bash
DRY_RUN=1 MOVIE_TITLE="Test Movie" MOVIE_YEAR="2024" ./create-and-commit.sh
```

### Local Repository

The scripts clone the repository to `/tmp/movies`. To work with a different location:

```bash
# Edit REPO_DIR in the scripts
REPO_DIR="/path/to/your/movies"
```

### Adding New Fields

To add new fields to the movie template:

1. Add the environment variable to `create-and-commit.sh`
2. Update the markdown template in the script
3. Document in `SKILL.md`
4. Update this README

## Contributing

1. Make changes on a feature branch
2. Test with `DRY_RUN=1`
3. Update documentation if needed
4. Submit a pull request

## License

Part of the [vcaldo/continuo](https://github.com/vcaldo/continuo) project.
