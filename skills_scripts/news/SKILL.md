# News Skill

## Descrição

Busca notícias recentes sobre uma região ou tema político usando web_search (Brave API). Retorna um resumo objetivo em português com links das fontes.

## Gatilhos

Ativar esta skill quando o usuário:
- Pede notícias de uma região específica (cidade, país)
- Quer saber notícias políticas (governo, congresso, partidos)
- Usa frases como "notícias sobre X", "o que está acontecendo em X", "novidades de X"

## Parâmetros

| Parâmetro | Descrição | Exemplos |
|-----------|-----------|----------|
| **região** | Cidade, estado ou país | L'Hospitalet de Llobregat, Barcelona, Brasil, España |
| **tema** | Área de interesse | política local, urbanismo, transporte, cultura, governo, Congresso |
| **idioma** | Idioma da busca | pt, es, en |

## Workflow

### Passo 1: Construir Query de Busca

Combinar região + tema + filtro de atualidade:

```
web_search: "[região] [tema] noticias últimas"
```

**Parâmetros recomendados:**
- `freshness`: "pw" (última semana) ou "pd" (últimas 24h)
- `search_lang`: idioma apropriado para a região
- `count`: 5-8 resultados

### Passo 2: Executar Busca

```javascript
web_search({
  query: "L'Hospitalet de Llobregat política local noticias",
  freshness: "pw",
  search_lang: "es",
  count: 6
})
```

### Passo 3: Filtrar e Resumir

1. **Ignorar resultados irrelevantes** (anúncios, conteúdo antigo)
2. **Evitar sobreposição** entre buscas relacionadas (ver seção abaixo)
3. **Resumir em português** de forma objetiva
4. **Incluir link da fonte** principal

### Passo 4: Formatar Resposta

```
📰 **Notícias de [Região] - [Tema]**

**[Título resumido]**
[Resumo objetivo em 2-3 frases em português]
🔗 [fonte.com](url)

**[Outro título]**
[Resumo]
🔗 [fonte.com](url)

---
*Última busca: [data]*
```

## Evitar Sobreposição

Quando há buscas para regiões próximas ou relacionadas, evitar duplicar informações:

### L'Hospitalet vs Barcelona

| L'Hospitalet de Llobregat | Barcelona |
|---------------------------|-----------|
| Política municipal de L'Hospitalet | Política municipal/metropolitana de Barcelona |
| Ajuntament de L'Hospitalet | Ajuntament de Barcelona, Generalitat |
| Bairros: Collblanc, Santa Eulàlia, Bellvitge | Bairros: Eixample, Gràcia, Sants |
| Urbanismo local específico | Transporte metro/cercanías geral |

**Queries diferenciadas:**
- L'Hospitalet: `"L'Hospitalet de Llobregat" -Barcelona política ayuntamiento noticias`
- Barcelona: `Barcelona ciudad política metropolitana transporte noticias`

### Brasil vs Espanha (política)

| Brasil | Espanha |
|--------|---------|
| Governo federal, Planalto | Gobierno, La Moncloa |
| Congresso Nacional, Câmara, Senado | Congreso de los Diputados, Senado |
| STF, TSE, ministros | Tribunal Supremo, Tribunal Constitucional |
| Lula, PT, oposição | Sánchez, PSOE, PP, Vox |

**Queries diferenciadas:**
- Brasil: `Brasil política governo Congresso Lula notícias`
- Espanha: `España política gobierno Congreso Sánchez noticias`

## Casos de Uso

### 1. L'Hospitalet de Llobregat - Política Local

```javascript
web_search({
  query: "\"L'Hospitalet de Llobregat\" política ayuntamiento urbanismo noticias",
  freshness: "pw",
  search_lang: "es",
  count: 6
})
```

**Resposta exemplo:**
```
📰 **Notícias de L'Hospitalet de Llobregat**

**Câmara aprova novo plano urbanístico para Bellvitge**
A prefeitura de L'Hospitalet aprovou um projeto de renovação urbana para o bairro de Bellvitge, incluindo novos espaços verdes e melhorias na acessibilidade. O investimento previsto é de 12 milhões de euros.
🔗 [elhospitalet.cat](https://...)

**Oposição critica gestão de transporte público local**
Partidos da oposição no ajuntament criticaram a falta de investimento em linhas de ônibus locais...
🔗 [lavanguardia.com](https://...)
```

### 2. Barcelona - Política e Transporte

```javascript
web_search({
  query: "Barcelona política metropolitana transporte TMB metro noticias",
  freshness: "pw",
  search_lang: "es",
  count: 6
})
```

**Resposta exemplo:**
```
📰 **Notícias de Barcelona - Transporte e Política**

**TMB anuncia extensão da linha L9 do metrô**
A TMB confirmou o cronograma para a extensão da linha L9, conectando novos bairros ao aeroporto. As obras devem iniciar em 2025.
🔗 [elperiodico.com](https://...)

**Generalitat e Ajuntament discordam sobre financiamento**
O governo regional e a prefeitura de Barcelona entraram em disputa sobre a divisão de custos para infraestrutura...
🔗 [ara.cat](https://...)
```

### 3. Brasil - Política Nacional

```javascript
web_search({
  query: "Brasil política governo Congresso STF Lula notícias",
  freshness: "pw",
  search_lang: "pt",
  count: 6
})
```

**Resposta exemplo:**
```
📰 **Notícias Políticas do Brasil**

**Congresso vota reforma tributária em segundo turno**
A Câmara dos Deputados aprovou em segundo turno a reforma tributária, com 375 votos a favor. O texto segue agora para o Senado.
🔗 [g1.globo.com](https://...)

**STF julga marco temporal de terras indígenas**
O Supremo Tribunal Federal retomou o julgamento sobre a tese do marco temporal...
🔗 [folha.uol.com.br](https://...)
```

### 4. Espanha - Política Nacional

```javascript
web_search({
  query: "España política gobierno Congreso PSOE PP Sánchez noticias",
  freshness: "pw",
  search_lang: "es",
  count: 6
})
```

**Resposta exemplo:**
```
📰 **Notícias Políticas da Espanha**

**Governo Sánchez enfrenta moção no Congresso**
O PSOE enfrentará uma moção apresentada pelo PP sobre a gestão econômica. A votação está prevista para quinta-feira.
🔗 [elpais.com](https://...)

**Comunidades autônomas negociam orçamento com Moncloa**
Representantes das comunidades autônomas se reuniram com o governo central para discutir a distribuição de fundos...
🔗 [elmundo.es](https://...)
```

## Ferramentas Utilizadas

| Ferramenta | Propósito |
|------------|-----------|
| `web_search` | Buscar notícias recentes via Brave API |

## Boas Práticas

1. **Use freshness** - Sempre filtrar por "pw" (semana) ou "pd" (24h) para notícias recentes
2. **Aspas para nomes compostos** - `"L'Hospitalet de Llobregat"` evita resultados errados
3. **Exclusão de sobreposição** - Use `-Barcelona` quando buscar só L'Hospitalet
4. **Resuma em português** - Mesmo que a fonte seja em espanhol/inglês
5. **Cite a fonte** - Sempre incluir link original
6. **Seja objetivo** - Resumir fatos, evitar opinião

## Fontes Confiáveis por Região

### Espanha / Catalunha
- La Vanguardia, El Periódico, Ara, El País, El Mundo
- Betevé (Barcelona), L'Hospitalet Diari

### Brasil
- G1, Folha de S.Paulo, Estadão, UOL, BBC Brasil
- Agência Brasil, Congresso em Foco

### Internacional
- Reuters, AFP, AP, BBC, EFE
