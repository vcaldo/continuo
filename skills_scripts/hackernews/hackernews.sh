#!/bin/bash
# hackernews.sh - Busca top posts do Hacker News
# Uso: ./hackernews.sh [count] [period]
#   count: número de posts (padrão: 5)
#   period: day, week, month (padrão: day)

set -euo pipefail

COUNT="${1:-5}"
PERIOD="${2:-day}"

# Calcula timestamp baseado no período
case "$PERIOD" in
    day|24h|hoje|ontem)
        SECONDS_AGO=86400
        ;;
    week|semana)
        SECONDS_AGO=604800
        ;;
    month|mês|mes)
        SECONDS_AGO=2592000
        ;;
    *)
        echo "Período inválido: $PERIOD"
        echo "Use: day, week, month"
        exit 1
        ;;
esac

TIMESTAMP=$(($(date +%s) - SECONDS_AGO))

# Busca posts da API (pega mais para garantir após ordenação)
FETCH_COUNT=$((COUNT * 3))
if [ "$FETCH_COUNT" -gt 100 ]; then
    FETCH_COUNT=100
fi

API_URL="https://hn.algolia.com/api/v1/search?tags=story&numericFilters=created_at_i%3E${TIMESTAMP}&hitsPerPage=${FETCH_COUNT}"

# Faz request e formata saída
curl -s "$API_URL" | jq -r --argjson count "$COUNT" '
    .hits 
    | sort_by(-.points) 
    | .[0:$count] 
    | to_entries 
    | .[] 
    | "#\(.key + 1) \(.value.title) - \(.value.points) pontos\n   🔗 \(.value.url // "https://news.ycombinator.com/item?id=\(.value.objectID)")\n   📝 \(.value.num_comments) comentários | por \(.value.author)\n"
'
