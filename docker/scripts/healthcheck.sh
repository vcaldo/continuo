#!/bin/bash
# docker/scripts/healthcheck.sh
# Health check for OpenClaw gateway

set -e

GATEWAY_PORT="${GATEWAY_PORT:-8080}"
TIMEOUT=5

# Check if supervisor is running
if ! pgrep -x supervisord > /dev/null; then
    echo "UNHEALTHY: supervisord not running"
    exit 1
fi

# Check if openclaw gateway process is running
if ! pgrep -f "openclaw.*gateway" > /dev/null; then
    echo "UNHEALTHY: openclaw gateway not running"
    exit 1
fi

# Check if gateway is responding (if it exposes an HTTP endpoint)
# OpenClaw gateway may not have a health endpoint, so we just check the process
# Uncomment below if gateway has HTTP health check:
# if ! curl -sf --max-time $TIMEOUT "http://localhost:${GATEWAY_PORT}/health" > /dev/null 2>&1; then
#     echo "UNHEALTHY: gateway not responding on port ${GATEWAY_PORT}"
#     exit 1
# fi

# Check if data directory is accessible
if [[ ! -d "/data/.openclaw" ]]; then
    echo "UNHEALTHY: /data/.openclaw directory missing"
    exit 1
fi

echo "HEALTHY: all checks passed"
exit 0
