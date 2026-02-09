# GitHub Trending Skill

Fetch trending repositories from GitHub to stay updated on what's hot in open source.

## Quick Start

```bash
# Make executable
chmod +x github-trending.sh

# Top 5 trending repos today
./github-trending.sh

# Top 10 Python repos this week
./github-trending.sh -n 10 -l python -p weekly
```

## Usage

```
./github-trending.sh [OPTIONS]

Options:
  -n, --count NUM       Number of repos to fetch (default: 5)
  -l, --language LANG   Filter by language (default: all)
  -p, --period PERIOD   Time period: daily, weekly, monthly (default: daily)
  -h, --help            Show this help message
```

## Examples

```bash
# All languages, daily, top 5
./github-trending.sh

# Top 10 repos
./github-trending.sh -n 10

# Python repos this week
./github-trending.sh -l python -p weekly

# Rust repos this month
./github-trending.sh -l rust -p monthly -n 3

# TypeScript daily
./github-trending.sh -l typescript
```

## Output Format

```
🔥 GitHub Trending (python) - this week

#1 owner/repo ⭐ +1,234 stars
   📝 Brief description of the repository
   💻 Python

#2 another/repo ⭐ +987 stars
   📝 Another description here
   💻 Python
```

## Supported Languages

Common language values:
- `python`, `javascript`, `typescript`, `rust`, `go`
- `java`, `c`, `cpp`, `csharp`, `ruby`, `php`
- `swift`, `kotlin`, `scala`, `elixir`, `haskell`
- `shell`, `lua`, `zig`, `nim`, `julia`

Check [GitHub Trending](https://github.com/trending) for full list.

## Requirements

- `curl` - HTTP client
- `python3` - For HTML parsing

## How It Works

1. Fetches `https://github.com/trending[/language]?since=[period]`
2. Parses HTML to extract repository information
3. Outputs formatted results with rankings, stars, and descriptions

## Cron Integration

Example: Daily trending digest at 9 AM

```bash
# crontab entry
0 9 * * * /path/to/github-trending.sh -n 5 > /tmp/trending.txt
```

Or use OpenClaw cron:
- **Schedule:** `0 9 * * *`
- **Prompt:** "Check GitHub Trending with the github-trending skill and summarize the top 5 repos"

## Limitations

- Data scraped from HTML (may break if GitHub changes layout)
- Rate limited by GitHub's standard web limits
- Stars count is approximate (shows gain in period, not total)

## Files

| File | Description |
|------|-------------|
| `github-trending.sh` | Main script |
| `SKILL.md` | Agent instructions |
| `README.md` | This documentation |

## License

Part of the [continuo](https://github.com/vcaldo/continuo) project.
