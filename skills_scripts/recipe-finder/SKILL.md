# Skill: Recipe Finder 🍳

Busca e sugere receitas de sites brasileiros populares para inspiração culinária e integração com o repositório vcaldo/receitas.

## Quando Usar

- Usuário pede sugestão de receita
- Cron diário para sugerir receita nova
- Busca por ingrediente específico
- Inspiração para refeições

## Fontes de Receitas

Buscar receitas nestes sites brasileiros (em ordem de preferência):

1. **Panelinha** (panelinha.com.br) - Receitas autorais de Rita Lobo
2. **TudoGostoso** (tudogostoso.com.br) - Maior acervo de receitas do Brasil
3. **Receiteria** (receiteria.com.br) - Receitas práticas e bem explicadas

## Como Buscar

### Método 1: Web Search
```
web_search: "receita [ingrediente/prato] site:panelinha.com.br OR site:tudogostoso.com.br OR site:receiteria.com.br"
```

### Método 2: Busca Aleatória por Categoria
Categorias populares para rotação:
- Massas e risotos
- Carnes (bovina, frango, porco)
- Peixes e frutos do mar
- Sopas e caldos
- Bolos e doces
- Saladas
- Comida brasileira tradicional
- Comida rápida (até 30 min)

### Método 3: Busca por Ingrediente
Quando usuário menciona ingrediente disponível:
```
web_search: "[ingrediente] receita fácil site:tudogostoso.com.br"
```

## Extração de Informações

Após encontrar URL da receita, usar `web_fetch` para extrair:

1. **Nome da receita** - título principal
2. **Tempo de preparo** - buscar "tempo", "preparo", "minutos"
3. **Dificuldade** - Fácil/Média/Difícil (inferir se não explícito)
4. **Ingredientes principais** - listar 3-5 ingredientes chave
5. **Descrição** - resumir em 2-3 linhas atraentes

## Formato de Saída

```
🍳 [Nome da Receita]

⏱️ Tempo: X minutos
📊 Dificuldade: Fácil/Média/Difícil
🥘 Ingredientes principais: ingrediente1, ingrediente2, ingrediente3...

📝 [descrição atraente 2-3 linhas que faça a pessoa querer fazer]

🔗 Fonte: [link completo]

Quer que eu adicione ao repositório de receitas?
```

## Integração com vcaldo/receitas

Se usuário confirmar que quer adicionar:

1. Extrair receita completa (ingredientes + modo de preparo)
2. Formatar em markdown seguindo padrão do repo
3. Criar arquivo em `receitas/[categoria]/[nome-da-receita].md`
4. Fazer commit e PR no repositório vcaldo/receitas

### Formato para o Repositório

```markdown
# [Nome da Receita]

**Tempo de preparo:** X minutos
**Dificuldade:** Fácil/Média/Difícil
**Porções:** X porções
**Fonte:** [link original]

## Ingredientes

- [ ] ingrediente 1
- [ ] ingrediente 2
...

## Modo de Preparo

1. Primeiro passo
2. Segundo passo
...

## Dicas

- Dica opcional sobre a receita

---
*Adicionado em: YYYY-MM-DD*
```

## Caso de Uso: Cron Diário

Para sugestão diária automática:

```
Prompt: "Sugira uma receita nova e interessante para adicionar ao repositório vcaldo/receitas"
```

Estratégia de rotação:
- Segunda: Prato principal
- Terça: Receita rápida (< 30 min)
- Quarta: Receita brasileira tradicional
- Quinta: Sobremesa ou doce
- Sexta: Comfort food
- Sábado: Receita elaborada (para quem tem tempo)
- Domingo: Almoço de família

## Exemplos de Busca

### Busca genérica
```
web_search: "receita fácil jantar site:panelinha.com.br"
```

### Por ingrediente
```
web_search: "receita frango desfiado site:tudogostoso.com.br"
```

### Por ocasião
```
web_search: "receita almoço domingo família site:receiteria.com.br"
```

### Sobremesa
```
web_search: "receita bolo fácil site:panelinha.com.br"
```

## Notas

- Preferir receitas com fotos (mais engajantes)
- Evitar receitas muito complexas para sugestões diárias
- Variar entre doce e salgado ao longo da semana
- Considerar sazonalidade (sopas no inverno, saladas no verão)
- Se a busca não retornar bons resultados, tentar outro site
