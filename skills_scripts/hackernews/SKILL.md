# Skill: Hacker News Top Posts

Busca os posts mais populares do Hacker News filtrados por período.

## API

Usa a API do Algolia HN: `https://hn.algolia.com/api/v1/search`

### Endpoint Principal

```
GET https://hn.algolia.com/api/v1/search?tags=story&numericFilters=created_at_i>{timestamp}&hitsPerPage={count}
```

### Parâmetros

| Parâmetro | Descrição | Valores |
|-----------|-----------|---------|
| `count` | Quantidade de posts | 1-50 (padrão: 5) |
| `period` | Período de busca | `day`, `week`, `month` (padrão: `day`) |

### Cálculo do Timestamp

```javascript
// Para últimas 24h:
const timestamp = Math.floor(Date.now() / 1000) - 86400;

// Para última semana:
const timestamp = Math.floor(Date.now() / 1000) - 604800;

// Para último mês:
const timestamp = Math.floor(Date.now() / 1000) - 2592000;
```

## Uso

### Exemplo de Chamada API

```bash
# Top 10 posts das últimas 24h, ordenados por pontos
curl "https://hn.algolia.com/api/v1/search?tags=story&numericFilters=created_at_i>$(date -d '24 hours ago' +%s)&hitsPerPage=50" \
  | jq -r '.hits | sort_by(-.points) | .[0:10] | .[] | "#\(.points) pontos - \(.title)\n   🔗 \(.url // "https://news.ycombinator.com/item?id=\(.objectID)")\n"'
```

### Exemplo de Resposta da API

```json
{
  "hits": [
    {
      "title": "Show HN: I built a thing",
      "url": "https://example.com",
      "points": 500,
      "num_comments": 200,
      "author": "user123",
      "objectID": "12345678",
      "created_at_i": 1707350400
    }
  ]
}
```

## Formato de Saída Esperado

```
#1 [título] - [X pontos]
   🔗 [link]
   📝 [breve contexto 1 linha]

#2 [título] - [X pontos]
   🔗 [link]
   📝 [breve contexto 1 linha]
```

## Instruções para o Agente

Quando solicitado a buscar top posts do Hacker News:

1. **Calcular timestamp** baseado no período solicitado
2. **Fazer request** para a API Algolia HN
3. **Ordenar por pontos** (campo `points`) em ordem decrescente
4. **Formatar saída** conforme template acima
5. **Gerar contexto** de 1 linha baseado no título/URL

### Períodos Suportados

- `day` / `24h` / `hoje` / `ontem` → últimas 24 horas
- `week` / `semana` → últimos 7 dias
- `month` / `mês` → últimos 30 dias

### Exemplo de Prompt

> "Me dê os top 5 posts do Hacker News da última semana"

**Resposta:**
```
#1 Show HN: GPT-5 Released - 2847 pontos
   🔗 https://openai.com/gpt5
   📝 OpenAI lança nova versão do modelo de linguagem

#2 The Future of Programming - 1523 pontos
   🔗 https://blog.example.com/future
   📝 Artigo sobre tendências em desenvolvimento de software

...
```

## Caso de Uso: Cron Diário

**Objetivo:** Receber top 3 links mais populares do dia anterior

**Prompt para cron:**
```
Busque os top 3 posts do Hacker News das últimas 24h e formate conforme SKILL.md
```

**Horário sugerido:** 09:00 UTC (início do dia)

## Notas

- A API Algolia não requer autenticação
- Rate limit é generoso (~10k requests/hora)
- Posts sem URL externa usam link do HN: `https://news.ycombinator.com/item?id={objectID}`
- O campo `num_comments` pode ser usado para filtrar discussões ativas
