---
name: weather
description: Buscar previsão do tempo para cidades específicas (sem API key).
homepage: https://wttr.in/:help
metadata: { "openclaw": { "emoji": "🌤️", "requires": { "bins": ["curl", "jq"] } } }
---

# Weather Skill

Busca previsão do tempo usando wttr.in (gratuito, sem API key).

## ⚠️ Importante: Códigos de Formato

| Código | Descrição | CUIDADO |
|--------|-----------|---------|
| `%c` | Condição (emoji: ☀️⛅🌧️❄️) | ✅ |
| `%C` | Condição (texto) | ✅ |
| `%t` | Temperatura atual | ✅ |
| `%f` | Sensação térmica | ✅ |
| `%w` | Vento (direção + velocidade) | ✅ |
| `%p` | Precipitação (mm) | ✅ |
| `%h` | Umidade | ✅ |
| `%P` | Pressão (hPa) | ✅ |
| `%u` | Índice UV | ✅ |
| `%S` | Nascer do sol | ✅ |
| `%s` | Pôr do sol | ✅ |
| `%D` | Amanhecer (dawn) | ✅ |
| `%d` | Anoitecer (dusk) | ✅ |
| `%l` | Nome da localidade | ✅ |
| `%m` | **Fase lunar** (🌑🌒🌓🌔🌕🌖🌗🌘) | ⚠️ NÃO é temp mínima! |
| `%M` | **Dia do ciclo lunar** (1-28) | ⚠️ NÃO é temp máxima! |

## Obter Temperatura Máxima/Mínima do Dia

**Não existe código direto.** Use o formato JSON:

```bash
# Obter max/min do dia via JSON
curl -s "wttr.in/Barcelona?format=j1" | jq -r '.weather[0] | "📈 Máx: \(.maxtempC)°C  📉 Mín: \(.mintempC)°C"'
```

## Script Completo Recomendado

```bash
#!/bin/bash
# Previsão do tempo para múltiplas cidades

get_weather() {
  local city="$1"
  local city_encoded="${city// /+}"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Nome da cidade (decode + para espaço)
  local location
  location=$(curl -s "wttr.in/${city_encoded}?format=%l" | sed 's/+/ /g')
  echo "📍 ${location}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Condição atual
  curl -s "wttr.in/${city_encoded}?format=%c+%C"
  echo ""
  
  # Temperatura atual e sensação
  curl -s "wttr.in/${city_encoded}?format=🌡️+Atual:+%t+(sensação+%f)"
  echo ""
  
  # Max/Min via JSON (única forma confiável)
  local json
  json=$(curl -s "wttr.in/${city_encoded}?format=j1")
  local maxtemp mintemp
  maxtemp=$(echo "$json" | jq -r '.weather[0].maxtempC')
  mintemp=$(echo "$json" | jq -r '.weather[0].mintempC')
  echo "📈 Máxima: ${maxtemp}°C  📉 Mínima: ${mintemp}°C"
  
  # Vento
  curl -s "wttr.in/${city_encoded}?format=💨+Vento:+%w"
  echo ""
  
  # Precipitação e umidade
  curl -s "wttr.in/${city_encoded}?format=🌧️+Precipitação:+%p++💧+Umidade:+%h"
  echo ""
  
  # Nascer e pôr do sol
  curl -s "wttr.in/${city_encoded}?format=🌅+Nascer:+%S++🌇+Pôr:+%s"
  echo ""
  echo ""
}

echo "🌤️ PREVISÃO DO TEMPO - $(date '+%A, %d de %B de %Y')"
echo ""

# Lista de cidades
cities=("Barcelona" "L'Hospitalet de Llobregat")

for city in "${cities[@]}"; do
  get_weather "$city"
done
```

## Uso Rápido (Uma Linha)

```bash
# Básico
curl -s "wttr.in/Barcelona?format=%l:+%c+%t+(sensação+%f)+💨+%w"

# Com max/min (requer jq)
echo "$(curl -s 'wttr.in/Barcelona?format=%c+%t') | $(curl -s 'wttr.in/Barcelona?format=j1' | jq -r '.weather[0] | "Max:\(.maxtempC)° Min:\(.mintempC)°"')"
```

## Formato Texto Compacto (Alternativa)

Se não precisar de max/min separados, use a visualização completa:

```bash
# Previsão de hoje em formato texto
curl -s "wttr.in/Barcelona?1&T&lang=pt"
```

## Opções Úteis

- `?lang=pt` - Saída em português
- `?format=j1` - Saída JSON (necessário para max/min)
- `?1` - Apenas hoje
- `?2` - Hoje + amanhã
- `?T` - Sem cores ANSI (para texto puro)
- `?m` - Unidades métricas (padrão)

## Dicas

1. **Encode espaços**: Use `+` ou `%20` para espaços em nomes de cidades
   - ✅ `L'Hospitalet+de+Llobregat` ou `L%27Hospitalet%20de%20Llobregat`

2. **Códigos de aeroporto**: `wttr.in/BCN` funciona

3. **Fallback**: Se wttr.in falhar, use Open-Meteo:
   ```bash
   curl -s "https://api.open-meteo.com/v1/forecast?latitude=41.38&longitude=2.17&current_weather=true&daily=temperature_2m_max,temperature_2m_min"
   ```

4. **Imagem PNG**: Para enviar como imagem:
   ```bash
   curl -s "wttr.in/Barcelona.png" -o /tmp/weather.png
   ```

## Emojis de Condição

| Emoji | Condição |
|-------|----------|
| ☀️ | Ensolarado |
| 🌤️ | Parcialmente nublado |
| ⛅ | Nublado |
| ☁️ | Muito nublado |
| 🌧️ | Chuva |
| 🌦️ | Chuva leve |
| ⛈️ | Tempestade |
| 🌨️ | Neve |
| 🌫️ | Névoa/Neblina |
| 💨 | Ventoso |
