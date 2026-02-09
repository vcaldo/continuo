# Trends Skill

Fetch trending topics from Google Trends and top headlines from major news portals.

## Overview

This skill enables an AI agent to:
- Get real-time trending searches from Google Trends
- Fetch main headlines from news portals
- Provide context explaining WHY topics are trending

## Supported Countries

| Country | Code | News Portals |
|---------|------|--------------|
| 🇧🇷 Brazil | BR | G1, Folha, UOL, Estadão |
| 🇪🇸 Spain | ES | El País, El Mundo, La Vanguardia |

## Usage

This is an agent skill - it provides instructions for the AI agent to follow when fetching trends. The agent uses standard web tools (`web_fetch`, `web_search`) to gather information.

### Example Prompts

```
"What's trending in Brazil today?"
"Trending topics in Spain"
"O que está em alta no Brasil?"
"¿Qué es tendencia en España?"
```

## Output Format

```
🔥 TRENDING TOPICS - [COUNTRY] - [DATE]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 GOOGLE TRENDS

1) [Topic #1]
   → [2-3 line explanation of why it's trending]

2) [Topic #2]
   → [Explanation]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📰 TOP HEADLINES

🔹 Portal: [Headline]
   [1-2 line summary]
   🔗 [link]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Cron Jobs

This skill is designed to run as scheduled tasks:

### Spain Daily
- **Schedule:** 8:00 CET daily
- **Country:** ES
- **Portals:** El País, El Mundo, La Vanguardia

### Brazil Daily
- **Schedule:** 9:00 BRT daily
- **Country:** BR
- **Portals:** G1, Folha, UOL, Estadão

## Data Sources

### Google Trends

The skill fetches trending data from:
- Google Trends RSS: `https://trends.google.com/trending/rss?geo=[COUNTRY]`
- Google Trends page: `https://trends.google.com/trending?geo=[COUNTRY]`

### News Portals

| Portal | URL | Language |
|--------|-----|----------|
| G1 | https://g1.globo.com/ | PT-BR |
| Folha | https://www.folha.uol.com.br/ | PT-BR |
| UOL | https://www.uol.com.br/ | PT-BR |
| Estadão | https://www.estadao.com.br/ | PT-BR |
| El País | https://elpais.com/ | ES |
| El Mundo | https://www.elmundo.es/ | ES |
| La Vanguardia | https://www.lavanguardia.com/ | ES |

## How It Works

1. **Fetch Trends** - Agent retrieves Google Trends data for the specified country
2. **Get Context** - For each trend, agent searches for news to explain why it's trending
3. **Fetch Headlines** - Agent visits each news portal and extracts the main headline
4. **Format Output** - Results are formatted in a clean, readable structure

## Files

| File | Description |
|------|-------------|
| `SKILL.md` | Detailed instructions for the AI agent |
| `README.md` | This documentation file |

## Requirements

- Access to `web_fetch` tool (for fetching web pages)
- Access to `web_search` tool (for context searches)
- No external dependencies or API keys required

## Contributing

To add support for a new country:

1. Identify the Google Trends geo code (e.g., `FR` for France)
2. Research major news portals for that country
3. Update `SKILL.md` with the new country configuration
4. Test the workflow with sample queries

## License

Part of the [continuo](https://github.com/vcaldo/continuo) project.
