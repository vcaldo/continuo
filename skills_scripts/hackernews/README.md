# 🔶 Hacker News Skill

Skill para buscar e formatar os posts mais populares do Hacker News.

## Funcionalidades

- ✅ Busca top posts por período (dia, semana, mês)
- ✅ Ordenação por pontos/upvotes
- ✅ Formatação limpa para leitura
- ✅ Suporte a contexto automático
- ✅ Sem necessidade de API key

## Uso Rápido

### Via Agente

```
"Top 5 posts do Hacker News de hoje"
"O que bombou no HN essa semana?"
"Busca os 3 links mais populares do dia anterior"
```

### Via Script

```bash
# Top 5 do dia
./hackernews.sh 5 day

# Top 10 da semana
./hackernews.sh 10 week

# Top 3 do mês
./hackernews.sh 3 month
```

## API Utilizada

[Algolia HN Search API](https://hn.algolia.com/api) - gratuita e sem autenticação.

### Endpoint

```
https://hn.algolia.com/api/v1/search?tags=story&numericFilters=created_at_i>{timestamp}&hitsPerPage={count}
```

## Formato de Saída

```
#1 Título do Post - 500 pontos
   🔗 https://link.com
   📝 Breve descrição do conteúdo

#2 Outro Post Popular - 350 pontos
   🔗 https://outro-link.com
   📝 Contexto sobre o post
```

## Arquivos

| Arquivo | Descrição |
|---------|-----------|
| `SKILL.md` | Instruções detalhadas para o agente |
| `README.md` | Esta documentação |
| `hackernews.sh` | Script bash para query direta |

## Caso de Uso: Cron

Configurar um cron para receber os top posts diariamente:

```
Horário: 09:00 UTC
Prompt: "Top 3 links mais populares do Hacker News das últimas 24h"
```

## Licença

MIT
