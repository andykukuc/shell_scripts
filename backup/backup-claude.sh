#!/bin/bash

# Claude Code backup to NAS (daily)
# Backs up: ~/.claude/, ~/scripts/, ~/Projects/
# Excludes: settings.json, API keys, sensitive data

set -e

NAS_HOST="nas-lp"
NAS_PORT="22357"
NAS_USER="admin"
NAS_PATH="/share/CE_CACHEDEV1_DATA/backups_andy/claude"

BACKUP_DIRS=(
    "$HOME/.claude/"
    "$HOME/scripts/"
    "$HOME/Projects/"
)

EXCLUDE_PATTERNS=(
    "--exclude=settings.json"        # Contains API keys
    "--exclude=.env"                 # Environment variables
    "--exclude=.env.local"
    "--exclude=*.pem"                # SSH/crypto keys
    "--exclude=*.key"
    "--exclude=*credentials*"
    "--exclude=node_modules"         # Large, not needed in backup
    "--exclude=.git"                 # Git can be restored from source
    "--exclude=*.tmp"
)

echo "[$(date)] Starting Claude backup to NAS..."

rsync \
    -avz \
    --delete \
    -e "ssh -p $NAS_PORT -i $SSH_KEY -o BatchMode=yes" \
    "${EXCLUDE_PATTERNS[@]}" \
    "${BACKUP_DIRS[@]}" \
    "$NAS_USER@$NAS_HOST:$NAS_PATH/"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date)] Backup complete ✓"
else
    echo "[$(date)] Backup failed with exit code $EXIT_CODE" >&2
    exit $EXIT_CODE
fi
