#!/bin/bash
# backup.sh - Runs on remote VM to create backup archive
set -euo pipefail

BACKUP_DIR="/tmp/openclaw-backup"
ARCHIVE="/tmp/openclaw-backup.zip"
ADMIN_USER="${ADMIN_USER:-admin}"
HOME_DIR="/home/$ADMIN_USER"

echo "=== OpenClaw Backup Script ==="
echo "Timestamp: $(date -Iseconds)"
echo "User: $ADMIN_USER"

# Clean previous backup
rm -rf "$BACKUP_DIR" "$ARCHIVE"
mkdir -p "$BACKUP_DIR"

# ============================================================================
# 1. OPENCLAW CONFIGURATION AND WORKSPACE
# ============================================================================
echo "Backing up OpenClaw configuration..."

if [ -d "$HOME_DIR/.openclaw" ]; then
    mkdir -p "$BACKUP_DIR/openclaw"
    cp -a "$HOME_DIR/.openclaw/." "$BACKUP_DIR/openclaw/"
    echo "  - .openclaw directory backed up"
else
    echo "  - WARNING: No .openclaw directory found"
fi

# ============================================================================
# 2. CRON JOBS
# ============================================================================
echo "Backing up cron jobs..."
mkdir -p "$BACKUP_DIR/cron"

# User crontab
crontab -l > "$BACKUP_DIR/cron/user-crontab" 2>/dev/null || echo "# No crontab" > "$BACKUP_DIR/cron/user-crontab"
echo "  - Cron jobs backed up"

# ============================================================================
# 3. ENVIRONMENT FILES
# ============================================================================
echo "Backing up environment files..."
mkdir -p "$BACKUP_DIR/env"

if [ -f "$HOME_DIR/.env" ]; then
    cp "$HOME_DIR/.env" "$BACKUP_DIR/env/dotenv"
    echo "  - .env backed up"
fi

# Backup shell customizations (custom additions only marker)
if [ -f "$HOME_DIR/.bashrc.local" ]; then
    cp "$HOME_DIR/.bashrc.local" "$BACKUP_DIR/env/bashrc.local"
    echo "  - .bashrc.local backed up"
fi

echo "  - Environment files processed"

# ============================================================================
# 4. SYSTEMD USER SERVICES
# ============================================================================
echo "Backing up systemd user services..."
mkdir -p "$BACKUP_DIR/systemd"

if [ -d "$HOME_DIR/.config/systemd/user" ]; then
    cp -a "$HOME_DIR/.config/systemd/user/." "$BACKUP_DIR/systemd/" 2>/dev/null || true
    echo "  - Systemd user services backed up"
else
    echo "  - No systemd user services found"
fi

# ============================================================================
# 5. CREATE MANIFEST
# ============================================================================
echo "Creating manifest..."

OPENCLAW_VERSION="unknown"
if command -v openclaw &> /dev/null; then
    OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo 'unknown')
fi

NODE_VERSION="unknown"
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version 2>/dev/null || echo 'unknown')
fi

cat > "$BACKUP_DIR/manifest.json" << EOF
{
    "version": "1.0",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "admin_user": "$ADMIN_USER",
    "openclaw_version": "$OPENCLAW_VERSION",
    "node_version": "$NODE_VERSION",
    "contents": {
        "openclaw": $([ -d "$BACKUP_DIR/openclaw" ] && echo "true" || echo "false"),
        "cron": true,
        "env": true,
        "systemd": $([ -d "$BACKUP_DIR/systemd" ] && [ "$(ls -A $BACKUP_DIR/systemd 2>/dev/null)" ] && echo "true" || echo "false")
    }
}
EOF

echo "  - Manifest created"

# ============================================================================
# 6. CREATE ARCHIVE
# ============================================================================
echo "Creating archive..."
cd "$BACKUP_DIR"
zip -rq "$ARCHIVE" .

echo ""
echo "=== Backup Complete ==="
echo "Archive: $ARCHIVE"
echo "Size: $(du -h $ARCHIVE | cut -f1)"
echo ""
echo "Note: Archive will be cleaned up after download"
