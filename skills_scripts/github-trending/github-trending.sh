#!/bin/bash
#
# github-trending.sh - Fetch trending repositories from GitHub
#
# Usage: ./github-trending.sh [OPTIONS]
#
# Options:
#   -n, --count NUM       Number of repos to fetch (default: 5)
#   -l, --language LANG   Filter by language (default: all)
#   -p, --period PERIOD   Time period: daily, weekly, monthly (default: daily)
#   -h, --help            Show this help message
#
# Examples:
#   ./github-trending.sh                    # Top 5 daily, all languages
#   ./github-trending.sh -n 10              # Top 10 daily
#   ./github-trending.sh -l python -p weekly # Top 5 Python repos this week
#   ./github-trending.sh -l rust -n 3       # Top 3 Rust repos today
#

set -euo pipefail

# Default values
COUNT=5
LANGUAGE=""
PERIOD="daily"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--count)
            COUNT="$2"
            shift 2
            ;;
        -l|--language)
            LANGUAGE="$2"
            shift 2
            ;;
        -p|--period)
            PERIOD="$2"
            shift 2
            ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate period
case "$PERIOD" in
    daily|weekly|monthly) ;;
    *)
        echo "Error: Invalid period '$PERIOD'. Use: daily, weekly, monthly" >&2
        exit 1
        ;;
esac

# Build URL
BASE_URL="https://github.com/trending"
if [[ -n "$LANGUAGE" ]]; then
    # URL encode the language (lowercase, spaces to hyphens)
    LANG_ENCODED=$(echo "$LANGUAGE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    URL="${BASE_URL}/${LANG_ENCODED}?since=${PERIOD}"
else
    URL="${BASE_URL}?since=${PERIOD}"
fi

# Fetch and parse trending page
fetch_trending() {
    local html
    html=$(curl -sL -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" "$URL")
    
    if [[ -z "$html" ]]; then
        echo "Error: Failed to fetch GitHub Trending page" >&2
        exit 1
    fi
    
    # Parse using Python for reliable HTML parsing
    python3 << PYTHON_SCRIPT
import re
from html.parser import HTMLParser
import html as html_module

html_content = '''$html'''

# Simple regex-based parsing (more reliable than complex HTML parsing)
# Find all article.Box-row elements
repos = []
pattern = r'<article class="Box-row">(.*?)</article>'
articles = re.findall(pattern, html_content, re.DOTALL)

for i, article in enumerate(articles[:$COUNT]):
    repo = {}
    
    # Extract repo name (owner/repo)
    name_match = re.search(r'<h2[^>]*>.*?<a[^>]*href="(/[^"]+)"[^>]*>', article, re.DOTALL)
    if name_match:
        repo['name'] = name_match.group(1).strip('/')
    
    # Extract description
    desc_match = re.search(r'<p class="[^"]*col-9[^"]*"[^>]*>(.*?)</p>', article, re.DOTALL)
    if desc_match:
        desc = desc_match.group(1).strip()
        desc = re.sub(r'<[^>]+>', '', desc)  # Remove HTML tags
        desc = html_module.unescape(desc)
        desc = ' '.join(desc.split())  # Normalize whitespace
        repo['description'] = desc if desc else 'No description'
    else:
        repo['description'] = 'No description'
    
    # Extract programming language
    lang_match = re.search(r'<span itemprop="programmingLanguage">(.*?)</span>', article)
    if lang_match:
        repo['language'] = lang_match.group(1).strip()
    else:
        repo['language'] = 'Not specified'
    
    # Extract stars gained in period
    stars_match = re.search(r'(\d[\d,]*)\s*stars\s*(today|this week|this month)', article, re.IGNORECASE)
    if stars_match:
        repo['stars_gained'] = stars_match.group(1).replace(',', '')
    else:
        repo['stars_gained'] = '?'
    
    if 'name' in repo:
        repos.append(repo)

# Output formatted results
period_text = {'daily': 'today', 'weekly': 'this week', 'monthly': 'this month'}['$PERIOD']
lang_text = '$LANGUAGE' if '$LANGUAGE' else 'all languages'

print(f"🔥 GitHub Trending ({lang_text}) - {period_text}")
print()

for i, repo in enumerate(repos, 1):
    print(f"#{i} {repo['name']} ⭐ +{repo['stars_gained']} stars")
    print(f"   📝 {repo['description'][:100]}{'...' if len(repo['description']) > 100 else ''}")
    print(f"   💻 {repo['language']}")
    print()
PYTHON_SCRIPT
}

fetch_trending
