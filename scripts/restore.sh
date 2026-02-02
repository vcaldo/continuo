#!/bin/bash
# restore.sh - Runs on new VM to restore from backup
set -euo pipefail

ADMIN_USER="${ADMIN_USER:-admin}"
RESTORE_DIR="/home/${ADMIN_USER}/.restore"
HOME_DIR="/home/${ADMIN_USER}"

echo "=== OpenClaw Restore Script ==="
echo "Timestamp: $(date -Iseconds)"
echo "User: $ADMIN_USER"

# Check if backup exists
if [ ! -d "$RESTORE_DIR" ] || [ -z "$(ls -A $RESTORE_DIR 2>/dev/null)" ]; then
    echo "No backup found at $RESTORE_DIR - performing fresh install"
    exit 0
fi

# Read manifest
if [ -f "$RESTORE_DIR/manifest.json" ]; then
    echo "Manifest found:"
    cat "$RESTORE_DIR/manifest.json"
    echo ""
fi

# ============================================================================
# 1. RESTORE OPENCLAW CONFIGURATION
# ============================================================================
echo "Restoring OpenClaw configuration..."

if [ -d "$RESTORE_DIR/openclaw" ]; then
    # Remove any existing .openclaw directory
    rm -rf "$HOME_DIR/.openclaw"

    # Restore from backup
    mkdir -p "$HOME_DIR/.openclaw"
    cp -a "$RESTORE_DIR/openclaw/." "$HOME_DIR/.openclaw/"

    # Fix ownership
    chown -R "${ADMIN_USER}:${ADMIN_USER}" "$HOME_DIR/.openclaw"

    # Fix permissions on sensitive files
    if [ -d "$HOME_DIR/.openclaw/credentials" ]; then
        chmod 700 "$HOME_DIR/.openclaw/credentials"
        chmod 600 "$HOME_DIR/.openclaw/credentials/"* 2>/dev/null || true
    fi

    if [ -f "$HOME_DIR/.openclaw/gateway.auth.token" ]; then
        chmod 600 "$HOME_DIR/.openclaw/gateway.auth.token"
    fi

    echo "  - OpenClaw configuration restored"
else
    echo "  - No OpenClaw backup found"
fi

# ============================================================================
# 2. RESTORE CRON JOBS
# ============================================================================
echo "Restoring cron jobs..."

if [ -f "$RESTORE_DIR/cron/user-crontab" ]; then
    # Only restore if not empty/default
    if grep -v "^#" "$RESTORE_DIR/cron/user-crontab" | grep -q .; then
        su - "${ADMIN_USER}" -c "crontab $RESTORE_DIR/cron/user-crontab"
        echo "  - User crontab restored"
    else
        echo "  - User crontab was empty, skipping"
    fi
else
    echo "  - No crontab backup found"
fi

# ============================================================================
# 3. RESTORE ENVIRONMENT FILES
# ============================================================================
echo "Restoring environment files..."

if [ -f "$RESTORE_DIR/env/dotenv" ]; then
    cp "$RESTORE_DIR/env/dotenv" "$HOME_DIR/.env"
    chown "${ADMIN_USER}:${ADMIN_USER}" "$HOME_DIR/.env"
    chmod 600 "$HOME_DIR/.env"
    echo "  - .env restored"
fi

if [ -f "$RESTORE_DIR/env/bashrc.local" ]; then
    cp "$RESTORE_DIR/env/bashrc.local" "$HOME_DIR/.bashrc.local"
    chown "${ADMIN_USER}:${ADMIN_USER}" "$HOME_DIR/.bashrc.local"

    # Source it from .bashrc if not already
    if ! grep -q "bashrc.local" "$HOME_DIR/.bashrc" 2>/dev/null; then
        echo '[ -f ~/.bashrc.local ] && source ~/.bashrc.local' >> "$HOME_DIR/.bashrc"
    fi
    echo "  - .bashrc.local restored"
fi

# ============================================================================
# 4. RESTORE SYSTEMD SERVICES
# ============================================================================
echo "Restoring systemd user services..."

if [ -d "$RESTORE_DIR/systemd" ] && [ "$(ls -A $RESTORE_DIR/systemd 2>/dev/null)" ]; then
    mkdir -p "$HOME_DIR/.config/systemd/user"
    cp -a "$RESTORE_DIR/systemd/." "$HOME_DIR/.config/systemd/user/"
    chown -R "${ADMIN_USER}:${ADMIN_USER}" "$HOME_DIR/.config/systemd"

    # Reload systemd for user
    su - "${ADMIN_USER}" -c "systemctl --user daemon-reload" 2>/dev/null || true
    echo "  - Systemd services restored"
else
    echo "  - No systemd services to restore"
fi

# ============================================================================
# 5. RESTART OPENCLAW GATEWAY
# ============================================================================
echo "Restarting OpenClaw gateway..."

su - "${ADMIN_USER}" -c 'source ~/.bashrc && openclaw gateway stop' 2>/dev/null || true
su - "${ADMIN_USER}" -c 'source ~/.bashrc && openclaw gateway install' || true
su - "${ADMIN_USER}" -c 'source ~/.bashrc && openclaw gateway start' || true
echo "  - OpenClaw gateway restarted"

# ============================================================================
# 6. CLEANUP
# ============================================================================
echo "Cleaning up restore directory..."
rm -rf "$RESTORE_DIR"

echo ""
echo "=== Restore Complete ==="
