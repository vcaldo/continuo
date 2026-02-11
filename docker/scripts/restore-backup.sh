#!/bin/bash
# docker/scripts/restore-backup.sh
# Extracts backup tarball on first container start
# Uses .initialized marker to prevent re-extraction on restarts

set -euo pipefail

BACKUP_FILE="${1:-/backups/backup.tar.gz}"
DATA_DIR="${2:-/data}"
MARKER="${DATA_DIR}/.initialized"
FORCE="${FORCE_RESTORE:-false}"

log() {
    echo "[restore] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

# Check for .zip backup (our format)
if [[ ! -f "$BACKUP_FILE" ]]; then
    BACKUP_ZIP="${BACKUP_FILE%.tar.gz}.zip"
    if [[ -f "$BACKUP_ZIP" ]]; then
        BACKUP_FILE="$BACKUP_ZIP"
    fi
fi

# If already initialized and not forcing, skip
if [[ -f "$MARKER" && "$FORCE" != "true" ]]; then
    log "Already initialized (marker: $MARKER), skipping extraction"
    log "Set FORCE_RESTORE=true to re-extract"
    exit 0
fi

# Check for backup file
if [[ ! -f "$BACKUP_FILE" ]]; then
    log "No backup file found at $BACKUP_FILE"
    log "Starting with empty data directory"
    mkdir -p "${DATA_DIR}/.openclaw"
    chown -R admin:admin "${DATA_DIR}"
    touch "$MARKER"
    exit 0
fi

log "Extracting backup from ${BACKUP_FILE} to ${DATA_DIR}..."
mkdir -p "${DATA_DIR}"

# Determine archive type and extract
if [[ "$BACKUP_FILE" == *.zip ]]; then
    log "Detected ZIP archive"
    # Our backup format: zip contains .openclaw/, workspace/, env/, etc.
    unzip -q -o "$BACKUP_FILE" -d "${DATA_DIR}"
elif [[ "$BACKUP_FILE" == *.tar.gz ]] || [[ "$BACKUP_FILE" == *.tgz ]]; then
    log "Detected tar.gz archive"
    tar -xzf "$BACKUP_FILE" -C "${DATA_DIR}"
else
    log "ERROR: Unknown archive format: $BACKUP_FILE"
    exit 1
fi

# Handle nested extraction if backup contains home/admin structure
if [[ -d "${DATA_DIR}/home/admin/.openclaw" ]]; then
    log "Flattening nested directory structure..."
    mv "${DATA_DIR}/home/admin/.openclaw" "${DATA_DIR}/.openclaw.tmp"
    mv "${DATA_DIR}/home/admin/workspace" "${DATA_DIR}/workspace.tmp" 2>/dev/null || true
    rm -rf "${DATA_DIR}/home"
    mv "${DATA_DIR}/.openclaw.tmp" "${DATA_DIR}/.openclaw"
    mv "${DATA_DIR}/workspace.tmp" "${DATA_DIR}/workspace" 2>/dev/null || true
fi

# Process environment variables from backup
if [[ -f "${DATA_DIR}/env/dotenv" ]]; then
    log "Found env/dotenv, will be sourced by OpenClaw"
    # Copy to expected location if needed
    mkdir -p "${DATA_DIR}/.openclaw"
    cp "${DATA_DIR}/env/dotenv" "${DATA_DIR}/.openclaw/.env" 2>/dev/null || true
fi

# Fix ownership (container runs as admin:admin)
log "Setting ownership to admin:admin..."
chown -R admin:admin "${DATA_DIR}"

# Create initialized marker with metadata
cat > "$MARKER" << EOF
{
    "initialized_at": "$(date -Iseconds)",
    "backup_file": "$BACKUP_FILE",
    "bot_name": "${BOT_NAME:-unknown}",
    "hostname": "$(hostname)"
}
EOF
chown admin:admin "$MARKER"

log "Restoration complete"
log "Contents of ${DATA_DIR}:"
ls -la "${DATA_DIR}" || true
