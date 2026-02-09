# News Skill

Skill para buscar notícias locais e políticas usando a API do Brave Search.

## Funcionalidades

- 🔍 Busca notícias recentes por região e tema
- 🌐 Suporte a múltiplos idiomas (pt, es, en)
- 📰 Resumo objetivo em português
- 🔗 Links para fontes originais
- ⏰ Filtro por atualidade (24h, semana)

## Casos de Uso

Esta skill é usada em 4 cron jobs:

| Cron | Região | Temas |
|------|--------|-------|
| Diário | L'Hospitalet de Llobregat | Política local, eventos, urbanismo |
| Diário | Barcelona | Política local, transporte, cultura |
| Diário | Brasil | Governo, Congresso, STF |
| Diário | Espanha | Governo, partidos, Congresso |

## Como Funciona

1. **Recebe** região + tema
2. **Busca** via `web_search` (Brave API) com filtro de freshness
3. **Filtra** resultados relevantes, evitando sobreposição
4. **Resume** em português de forma objetiva
5. **Retorna** resumo + link da fonte

## Parâmetros

| Parâmetro | Tipo | Descrição |
|-----------|------|-----------|
| `região` | string | Cidade, estado ou país |
| `tema` | string | Área de interesse (política, cultura, etc) |
| `idioma` | string | Idioma da busca (pt, es, en) |
| `freshness` | string | "pd" (24h) ou "pw" (semana) |

## Evitando Sobreposição

Quando há buscas para regiões próximas (ex: L'Hospitalet e Barcelona), a skill usa técnicas para evitar duplicação:

- Queries específicas com aspas: `"L'Hospitalet de Llobregat"`
- Exclusão de termos: `-Barcelona`
- Foco em fontes locais

Veja SKILL.md para detalhes completos.

## Arquivos

```
skills_scripts/news/
├── README.md   # Esta documentação
└── SKILL.md    # Instruções detalhadas para o agente
```

## Exemplo de Uso

```
Usuário: "Me dê as notícias de L'Hospitalet"

Agente executa:
web_search({
  query: "\"L'Hospitalet de Llobregat\" política urbanismo noticias",
  freshness: "pw",
  search_lang: "es",
  count: 6
})

Resposta:
📰 **Notícias de L'Hospitalet de Llobregat**

**Câmara aprova novo plano urbanístico...**
[resumo em português]
🔗 elhospitalet.cat
```

## Licença

Parte do projeto [continuo](https://github.com/vcaldo/continuo).
