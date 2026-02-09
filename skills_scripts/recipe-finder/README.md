# Recipe Finder 🍳

Skill para buscar e sugerir receitas de sites brasileiros populares.

## Objetivo

Fornecer sugestões de receitas interessantes para:
- Inspiração diária de refeições
- Integração com o repositório [vcaldo/receitas](https://github.com/vcaldo/receitas)
- Descoberta de novas receitas baseadas em ingredientes disponíveis

## Fontes

| Site | URL | Especialidade |
|------|-----|---------------|
| Panelinha | panelinha.com.br | Receitas autorais de Rita Lobo |
| TudoGostoso | tudogostoso.com.br | Maior acervo brasileiro |
| Receiteria | receiteria.com.br | Receitas práticas |

## Uso

### Comando Manual

Peça ao agente:
- "Sugira uma receita para o jantar"
- "Quero uma receita com frango"
- "Receita de sobremesa fácil"

### Cron Automático

Configurar cron job para sugestão diária:

```bash
# Sugestão diária às 10h
openclaw cron add \
  --schedule "0 10 * * *" \
  --prompt "Sugira uma receita nova para adicionar ao repositório vcaldo/receitas" \
  --target telegram
```

## Formato de Saída

```
🍳 Strogonoff de Frango

⏱️ Tempo: 40 minutos
📊 Dificuldade: Fácil
🥘 Ingredientes principais: frango, creme de leite, champignon, catchup

📝 Um clássico brasileiro que agrada toda a família! Cremoso e saboroso, 
perfeito para acompanhar arroz branco e batata palha.

🔗 Fonte: https://www.tudogostoso.com.br/receita/strogonoff-frango

Quer que eu adicione ao repositório de receitas?
```

## Integração com vcaldo/receitas

Quando o usuário confirmar a adição:

1. Extrai receita completa do site fonte
2. Formata em markdown padronizado
3. Cria arquivo no repositório vcaldo/receitas
4. Faz commit e abre PR

## Estrutura

```
skills_scripts/recipe-finder/
├── README.md      # Esta documentação
└── SKILL.md       # Instruções para o agente
```

## Rotação Semanal (Cron)

Para manter variedade nas sugestões:

| Dia | Tema |
|-----|------|
| Segunda | Prato principal |
| Terça | Receita rápida (< 30 min) |
| Quarta | Comida brasileira tradicional |
| Quinta | Sobremesa ou doce |
| Sexta | Comfort food |
| Sábado | Receita elaborada |
| Domingo | Almoço de família |

## Licença

MIT - Parte do projeto [continuo](https://github.com/vcaldo/continuo)
