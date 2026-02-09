# Trends Skill

## Description

Enables the agent to fetch trending topics from Google Trends and top headlines from major news portals for a specific country. The skill provides context explaining WHY each topic is trending.

## Trigger

Activate this skill when the user:
- Asks about trending topics, trending news, or what's hot
- Wants to know what's happening in a specific country (BR, ES)
- Requests Google Trends data
- Uses phrases like "what's trending", "news today", "trending in Spain/Brazil"

## Supported Countries

| Country | Code | News Portals |
|---------|------|--------------|
| Brazil | BR | G1, Folha de S.Paulo, UOL, Estadão |
| Spain | ES | El País, El Mundo, La Vanguardia |

## Workflow

### Step 1: Fetch Google Trends

Use `web_fetch` to get real-time trending searches from Google Trends:

**For Brazil:**
```
web_fetch: https://trends.google.com/trending?geo=BR&hours=24
```

**For Spain:**
```
web_fetch: https://trends.google.com/trending?geo=ES&hours=24
```

If the above doesn't work, use `web_search`:
```
web_search: "Google Trends [country] today site:trends.google.com"
```

Or fetch the RSS feed:
```
web_fetch: https://trends.google.com/trending/rss?geo=BR
web_fetch: https://trends.google.com/trending/rss?geo=ES
```

### Step 2: Get Context for Trends

For each top trend (limit to 5-10), search for context:

```
web_search: "[trend topic] news today why trending"
```

This helps explain WHY the topic is trending (sports result, political event, celebrity news, etc.)

### Step 3: Fetch Headlines from News Portals

Use `web_fetch` to get headlines from each portal:

**Brazil:**
```
web_fetch: https://g1.globo.com/
web_fetch: https://www.folha.uol.com.br/
web_fetch: https://www.uol.com.br/
web_fetch: https://www.estadao.com.br/
```

**Spain:**
```
web_fetch: https://elpais.com/
web_fetch: https://www.elmundo.es/
web_fetch: https://www.lavanguardia.com/
```

Extract the main headline (usually the first H1 or prominent article).

### Step 4: Format Output

Present the results in this exact format:

```
🔥 TRENDING TOPICS - [PAÍS] - [DATA]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 GOOGLE TRENDS

1) [Assunto #1]
   → [Explicação de 2-3 linhas sobre por que está em alta]

2) [Assunto #2]
   → [Explicação de 2-3 linhas]

3) [Assunto #3]
   → [Explicação de 2-3 linhas]

[... até 5-10 trends]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📰 MANCHETES PRINCIPAIS

🔹 G1: [Título da manchete]
   [Resumo em 1-2 linhas]
   🔗 [link]

🔹 Folha: [Título da manchete]
   [Resumo em 1-2 linhas]
   🔗 [link]

[... demais portais]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| country | Yes | - | Country code: BR or ES |
| portals | No | All | List of portals to check |
| limit | No | 5 | Number of trends to show |

## Cron Jobs Configuration

This skill is designed to run as scheduled cron jobs:

### Spain Daily Trends
```
Schedule: Every morning 8:00 CET
Country: ES
Portals: El País, El Mundo, La Vanguardia
```

### Brazil Daily Trends
```
Schedule: Every morning 9:00 BRT
Country: BR
Portals: G1, Folha, UOL, Estadão
```

## Example Interactions

**User:** "O que está em alta no Brasil hoje?"

**Agent:**
1. `web_fetch`: Google Trends RSS for BR
2. `web_search`: Context for each top trend
3. `web_fetch`: Headlines from G1, Folha, UOL, Estadão
4. Format and present results

**User:** "Trending topics in Spain"

**Agent:**
1. `web_fetch`: Google Trends RSS for ES
2. `web_search`: Context for each top trend
3. `web_fetch`: Headlines from El País, El Mundo, La Vanguardia
4. Format and present results

**User:** "Just give me Google Trends for Brazil"

**Agent:**
1. Fetch only Google Trends (skip news portals)
2. Provide context for each trend
3. Format output (trends section only)

## Tools Used

| Tool | Purpose |
|------|---------|
| `web_fetch` | Get Google Trends RSS/page, fetch news portal homepages |
| `web_search` | Search for context explaining why topics are trending |

## Error Handling

| Issue | Solution |
|-------|----------|
| Google Trends unavailable | Use web_search as fallback |
| Portal blocked/timeout | Skip and note in output |
| No trends found | Report and check alternative sources |

## Best Practices

1. **Always provide context** - Don't just list trends, explain WHY they're trending
2. **Be concise** - 2-3 lines per trend explanation is ideal
3. **Include links** - Always link to the news source
4. **Time-sensitive** - Trends change fast, always note the date/time
5. **Respect limits** - Don't overload with too many requests
6. **Language matching** - Use Portuguese for BR, Spanish for ES

## News Portal Reference

### Brazil

| Portal | URL | Type |
|--------|-----|------|
| G1 | https://g1.globo.com/ | General news (Globo) |
| Folha | https://www.folha.uol.com.br/ | Traditional newspaper |
| UOL | https://www.uol.com.br/ | Portal/aggregator |
| Estadão | https://www.estadao.com.br/ | Traditional newspaper |

### Spain

| Portal | URL | Type |
|--------|-----|------|
| El País | https://elpais.com/ | Major newspaper |
| El Mundo | https://www.elmundo.es/ | Major newspaper |
| La Vanguardia | https://www.lavanguardia.com/ | Catalan newspaper |

## Output Example

```
🔥 TRENDING TOPICS - BRASIL - 09/02/2025

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 GOOGLE TRENDS

1) Flamengo x Palmeiras
   → Clássico decisivo pelo Campeonato Brasileiro acontece hoje
     no Maracanã. Times disputam a liderança da tabela.

2) Selic
   → Banco Central anuncia nova taxa de juros. Mercado reagiu
     com volatilidade após decisão do Copom ontem.

3) Carnaval 2025
   → Preparativos para o carnaval dominam notícias com ensaios
     das escolas de samba e divulgação dos blocos de rua.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📰 MANCHETES PRINCIPAIS

🔹 G1: Copom mantém Selic em 13,75% e sinaliza cortes em 2025
   Decisão unânime do comitê mantém juros estáveis pelo 4º mês consecutivo
   🔗 https://g1.globo.com/economia/noticia/...

🔹 Folha: Lula anuncia pacote de investimentos em infraestrutura
   Governo prevê R$ 50 bilhões para rodovias e ferrovias
   🔗 https://www.folha.uol.com.br/mercado/...

🔹 UOL: Flamengo e Palmeiras decidem liderança em clássico
   Jogo no Maracanã tem ingressos esgotados
   🔗 https://www.uol.com.br/esporte/...

🔹 Estadão: Inflação desacelera em janeiro, mas alimentos pesam
   IPCA registra 0,42% no mês
   🔗 https://www.estadao.com.br/economia/...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
