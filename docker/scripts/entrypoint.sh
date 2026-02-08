#!/bin/bash
# docker/scripts/entrypoint.sh
# Container entrypoint: runs restoration, then starts supervisor

set -e

log() {
    echo "[entrypoint] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

# Ensure we have a bot name
if [[ -z "${BOT_NAME}" ]]; then
    log "ERROR: BOT_NAME environment variable is required"
    exit 1
fi

log "Starting container for bot: ${BOT_NAME}"

# Run restoration as root (handles chown)
/usr/local/bin/restore-backup.sh

# Set up symbolic links from /data to OpenClaw home
# This allows the container to use /data as persistent storage
# while OpenClaw expects files in /home/admin/.openclaw
OPENCLAW_HOME="/home/admin/.openclaw"

if [[ -d "/data/.openclaw" ]]; then
    log "Linking /data/.openclaw to ${OPENCLAW_HOME}"
    
    # Remove existing directory if it's not a symlink
    if [[ -d "${OPENCLAW_HOME}" && ! -L "${OPENCLAW_HOME}" ]]; then
        # Preserve bin directory (OpenClaw installation)
        if [[ -d "${OPENCLAW_HOME}/bin" ]]; then
            mkdir -p /data/.openclaw/bin
            cp -rn "${OPENCLAW_HOME}/bin/"* /data/.openclaw/bin/ 2>/dev/null || true
        fi
        rm -rf "${OPENCLAW_HOME}"
    fi
    
    # Create symlink if not exists
    if [[ ! -L "${OPENCLAW_HOME}" ]]; then
        ln -sf /data/.openclaw "${OPENCLAW_HOME}"
    fi
    
    chown -h admin:admin "${OPENCLAW_HOME}"
fi

# Set up workspace symlink if workspace exists in data
if [[ -d "/data/workspace" && ! -L "/home/admin/.openclaw/workspace" ]]; then
    log "Linking /data/workspace to workspace"
    rm -rf /home/admin/.openclaw/workspace 2>/dev/null || true
    ln -sf /data/workspace /home/admin/.openclaw/workspace
    chown -h admin:admin /home/admin/.openclaw/workspace
fi

# Install cron jobs if present
if [[ -d "/data/cron" && -n "$(ls -A /data/cron 2>/dev/null)" ]]; then
    log "Installing cron jobs..."
    cat /data/cron/* 2>/dev/null | crontab -u admin - || log "Warning: Failed to install crontab"
fi

# Start cron daemon in background
log "Starting cron daemon..."
cron

log "Starting supervisor..."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
