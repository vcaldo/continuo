---
name: weather
description: Buscar previsão do tempo para cidades específicas (sem API key).
homepage: https://wttr.in/:help
metadata: { "openclaw": { "emoji": "🌤️", "requires": { "bins": ["curl"] } } }
---

# Weather Skill

Busca previsão do tempo usando wttr.in (gratuito, sem API key).

## Uso Rápido

### Uma cidade

```bash
curl -s "wttr.in/Barcelona?format=%l:+%c+%t+(feels+%f)+|+💨+%w+|+💧+%p+|+%h"
```

### Múltiplas cidades (loop)

```bash
for city in "Barcelona" "L'Hospitalet+de+Llobregat" "Madrid"; do
  echo "📍 $(curl -s "wttr.in/${city}?format=%l")"
  curl -s "wttr.in/${city}?format=%c+%t+(sensação+%f)+|+Máx:+%M+Mín:+%m"
  curl -s "wttr.in/${city}?format=💨+Vento:+%w+|+💧+Precip:+%p+|+Umidade:+%h"
  echo ""
done
```

## Formato Detalhado para Previsão Diária

```bash
# Previsão completa de hoje (formato texto compacto)
curl -s "wttr.in/Barcelona?1&T&lang=pt"
```

### Formato Customizado Recomendado

Para cada cidade, use este formato que inclui todos os dados pedidos:

```bash
city="Barcelona"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 $(curl -s "wttr.in/${city}?format=%l") - $(date +%d/%m/%Y)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
curl -s "wttr.in/${city}?format=Agora:+%c+%t+(sensação+%f)"
curl -s "wttr.in/${city}?format=📈+Máx:+%M++📉+Mín:+%m"  
curl -s "wttr.in/${city}?format=💨+Vento:+%w"
curl -s "wttr.in/${city}?format=💧+Chance+precip:+%p++|++Umidade:+%h"
curl -s "wttr.in/${city}?format=☀️+UV:+%u++|++🌅+Nascer:+%S++🌇+Pôr:+%s"
echo ""
```

## Códigos de Formato

| Código | Descrição |
|--------|-----------|
| `%c` | Condição (emoji: ☀️⛅🌧️❄️) |
| `%t` | Temperatura atual |
| `%f` | Sensação térmica |
| `%M` | Temperatura máxima |
| `%m` | Temperatura mínima |
| `%w` | Vento (direção + velocidade) |
| `%p` | Chance de precipitação |
| `%h` | Umidade |
| `%u` | Índice UV |
| `%S` | Nascer do sol |
| `%s` | Pôr do sol |
| `%l` | Nome da localidade |

## Opções Úteis

- `?lang=pt` - Saída em português
- `?1` - Apenas hoje
- `?2` - Hoje + amanhã
- `?T` - Sem cores ANSI (para texto puro)
- `?m` - Unidades métricas (padrão)
- `?M` - Evitar sequências de escape

## Exemplo Completo: Múltiplas Cidades

```bash
#!/bin/bash
# Previsão do tempo para múltiplas cidades

cities=("Barcelona" "L'Hospitalet+de+Llobregat")

echo "🌤️ PREVISÃO DO TEMPO - $(date '+%A, %d de %B de %Y')"
echo ""

for city in "${cities[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  location=$(curl -s "wttr.in/${city}?format=%l")
  echo "📍 ${location}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Condição atual
  curl -s "wttr.in/${city}?format=%c+%C"
  
  # Temperaturas
  curl -s "wttr.in/${city}?format=🌡️+Atual:+%t+(sensação+%f)"
  curl -s "wttr.in/${city}?format=📈+Máxima:+%M++📉+Mínima:+%m"
  
  # Vento e precipitação
  curl -s "wttr.in/${city}?format=💨+Vento:+%w"
  curl -s "wttr.in/${city}?format=🌧️+Precipitação:+%p"
  curl -s "wttr.in/${city}?format=💧+Umidade:+%h"
  
  # Sol
  curl -s "wttr.in/${city}?format=🌅+Nascer:+%S++🌇+Pôr:+%s"
  
  echo ""
done
```

## Dicas

1. **Encode espaços**: Use `+` para espaços em nomes de cidades
   - ✅ `L'Hospitalet+de+Llobregat`
   - ❌ `L'Hospitalet de Llobregat`

2. **Códigos de aeroporto**: `wttr.in/BCN` funciona

3. **Fallback JSON** (Open-Meteo): Se wttr.in falhar, use:
   ```bash
   curl -s "https://api.open-meteo.com/v1/forecast?latitude=41.38&longitude=2.17&current_weather=true"
   ```

4. **Imagem PNG**: Para enviar como imagem:
   ```bash
   curl -s "wttr.in/Barcelona.png" -o /tmp/weather.png
   ```

## Emojis de Condição (referência)

| Emoji | Condição |
|-------|----------|
| ☀️ | Ensolarado |
| 🌤️ | Parcialmente nublado |
| ⛅ | Nublado |
| ☁️ | Muito nublado |
| 🌧️ | Chuva |
| ⛈️ | Tempestade |
| 🌨️ | Neve |
| 🌫️ | Névoa/Neblina |
| 💨 | Ventoso |
