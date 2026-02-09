# Weather Skill 🌤️

Skill para buscar previsão do tempo usando serviços gratuitos (sem API key).

## Funcionalidades

- ✅ Temperatura atual, máxima e mínima
- ✅ Condições climáticas com emojis
- ✅ Chance de precipitação
- ✅ Velocidade e direção do vento
- ✅ Umidade relativa
- ✅ Horário de nascer/pôr do sol
- ✅ Suporte a múltiplas cidades
- ✅ Formato em português

## Uso

### Exemplo: Previsão para hoje

```
Buscar previsão do tempo para HOJE em: 
1) Barcelona 
2) L'Hospitalet de Llobregat
```

### Saída esperada

```
🌤️ PREVISÃO DO TEMPO - Segunda, 10 de Fevereiro de 2025

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Barcelona, Spain
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⛅ Partly cloudy
🌡️ Atual: +12°C (sensação +10°C)
📈 Máxima: +14°C  📉 Mínima: +8°C
💨 Vento: ↗12km/h
🌧️ Precipitação: 10%
💧 Umidade: 65%
🌅 Nascer: 07:42  🌇 Pôr: 18:15

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 L'Hospitalet de Llobregat, Spain
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⛅ Partly cloudy
🌡️ Atual: +11°C (sensação +9°C)
📈 Máxima: +13°C  📉 Mínima: +7°C
💨 Vento: ↗10km/h
🌧️ Precipitação: 15%
💧 Umidade: 68%
🌅 Nascer: 07:42  🌇 Pôr: 18:15
```

## Serviços Utilizados

### wttr.in (primário)
- Gratuito, sem API key
- Suporta formatos customizados
- Boa cobertura global
- Documentação: https://wttr.in/:help

### Open-Meteo (fallback)
- API JSON gratuita
- Sem limites de requisição
- Requer coordenadas (lat/lon)
- Documentação: https://open-meteo.com/en/docs

## Dicas de Uso

1. **Nomes de cidades com espaços**: Substituir espaços por `+`
2. **Cidades com apóstrofo**: Funciona normalmente (L'Hospitalet)
3. **Códigos de aeroporto**: BCN, MAD, LHR funcionam como atalhos

## Arquivos

- `SKILL.md` - Instruções completas para o agente
- `README.md` - Esta documentação

## Requisitos

- `curl` instalado no sistema
- Conexão com internet

## Licença

Parte do projeto continuo.
