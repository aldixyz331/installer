#!/bin/bash
# =====================================================
# NOTIFIKASI BACKUP (TELEGRAM + DISCORD)
# =====================================================

# === KONFIGURASI ===
TELEGRAM_BOT_TOKEN="ISI_TOKEN_BOT_TELEGRAM_KAMU"
TELEGRAM_CHAT_ID="ISI_CHAT_ID_KAMU"
DISCORD_WEBHOOK_URL="ISI_WEBHOOK_DISCORD_KAMU"

BACKUP_LOG="/root/backup-status.log"
BACKUP_PATH="/var/lib/pterodactyl/backups"

# === GENERATE REPORT ===
DATE=$(date +"%Y-%m-%d %H:%M")
COUNT=$(ls -1 "$BACKUP_PATH"/*.tar.gz 2>/dev/null | wc -l)
SIZE=$(du -sh "$BACKUP_PATH" | awk '{print $1}')

MESSAGE="✅ *Backup Berhasil!*\nTanggal: $DATE\nTotal file: $COUNT\nUkuran total: $SIZE\nLokasi: $BACKUP_PATH"

echo -e "$MESSAGE" > "$BACKUP_LOG"

# === TELEGRAM ===
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}" \
    -d "text=${MESSAGE}" \
    -d "parse_mode=Markdown"

# === DISCORD ===
curl -s -H "Content-Type: application/json" \
     -X POST -d "{\"content\": \"${MESSAGE}\"}" \
     "$DISCORD_WEBHOOK_URL"

echo "Notifikasi dikirim ke Telegram & Discord!"