#!/bin/bash
# =====================================================
# AUTO BACKUP PTERODACTYL SERVER DATA
# =====================================================
# Simpan semua data container game di /var/lib/pterodactyl/volumes
# Output: /var/lib/pterodactyl/backups/<server-id>-<date>.tar.gz
# =====================================================

BACKUP_DIR="/var/lib/pterodactyl/backups"
VOLUME_DIR="/var/lib/pterodactyl/volumes"

mkdir -p $BACKUP_DIR

echo "=== [1/3] Mulai backup server ==="
DATE=$(date +"%Y-%m-%d_%H-%M")

for SERVER_DIR in $VOLUME_DIR/*; do
  if [ -d "$SERVER_DIR" ]; then
    SERVER_ID=$(basename "$SERVER_DIR")
    FILE="$BACKUP_DIR/${SERVER_ID}-${DATE}.tar.gz"
    echo "📦 Membackup $SERVER_ID → $FILE"
    tar -czf "$FILE" -C "$SERVER_DIR" .
  fi
done

echo "✅ Semua server berhasil dibackup di: $BACKUP_DIR"