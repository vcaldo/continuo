# GitHub Trending Skill

## Description

Enables the agent to fetch trending repositories from GitHub Trending page. Provides information about the hottest repositories gaining stars, filtered by language and time period.

## Trigger

Activate this skill when the user:
- Asks about trending repositories on GitHub
- Wants to know what's popular/hot in open source
- Asks for top repos in a specific language
- Uses phrases like "what's trending on GitHub", "popular repos", "hot projects"
- Requests trending repos for daily/weekly analysis

## Parameters

| Parameter | Description | Default | Values |
|-----------|-------------|---------|--------|
| count | Number of repos to fetch | 5 | 1-25 |
| language | Programming language filter | all | python, rust, go, javascript, typescript, etc. |
| period | Time range for trending | daily | daily, weekly, monthly |

## Workflow

### Step 1: Determine Parameters

Extract from user request:
- **Count**: How many repos? (default: 5)
- **Language**: Specific language or all?
- **Period**: Today (daily), this week (weekly), or this month (monthly)?

### Step 2: Execute Script

Run the script with appropriate parameters:

```bash
cd /home/admin/.openclaw/workspace/continuo/skills_scripts/github-trending
./github-trending.sh -n COUNT -l LANGUAGE -p PERIOD
```

**Examples:**

```bash
# Top 5 trending repos today (all languages)
./github-trending.sh

# Top 10 Python repos this week
./github-trending.sh -n 10 -l python -p weekly

# Top 3 Rust repos this month
./github-trending.sh -n 3 -l rust -p monthly

# Top 5 JavaScript repos today
./github-trending.sh -l javascript
```

### Step 3: Present Results

The script outputs formatted results:

```
🔥 GitHub Trending (python) - this week

#1 owner/repo ⭐ +1,234 stars
   📝 Brief description of the repository
   💻 Python

#2 another/repo ⭐ +987 stars
   📝 Another description
   💻 Python
```

## Output Format

Each repository includes:
- **Rank**: Position in trending (#1, #2, etc.)
- **Name**: Full repo name (owner/repo)
- **Stars gained**: Stars earned in the period
- **Description**: One-line summary (truncated to 100 chars)
- **Language**: Primary programming language

## Example Interactions

**User:** "What's trending on GitHub?"
```bash
./github-trending.sh -n 5
```

**User:** "Show me top 10 Python repos this week"
```bash
./github-trending.sh -n 10 -l python -p weekly
```

**User:** "Any hot Rust projects?"
```bash
./github-trending.sh -l rust -n 5
```

**User:** "Give me the top 3 JavaScript repos of the month"
```bash
./github-trending.sh -n 3 -l javascript -p monthly
```

## Cron Use Case

For daily trending digest at 9:00 AM:

**Schedule:** `0 9 * * *`
**Model:** Default (claude-sonnet)
**Prompt:**
```
Check GitHub Trending and report the top 5 repositories (all languages) from yesterday.
Use the github-trending skill and summarize any interesting patterns or noteworthy projects.
```

## Notes

- Data is scraped from github.com/trending (no API key needed)
- Results refresh roughly every hour on GitHub's side
- Some repos may show "?" for stars if the format changes
- Language names should be lowercase (python, rust, go, etc.)
- The script requires: curl, python3

## Error Handling

If the script fails:
1. Check network connectivity
2. Verify GitHub Trending page is accessible
3. Try without language filter first
4. Report any parsing errors to maintain the skill
