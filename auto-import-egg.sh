#!/bin/bash
# =====================================================
# AUTO IMPORT EGGS via PTERODACTYL API
# =====================================================
# Usage:
#   sudo bash auto-import-eggs.sh <PANEL_URL> <ADMIN_API_KEY>
# Example:
#   sudo bash auto-import-eggs.sh https://panel.trycloudflare.com abc123xyz
# =====================================================

PANEL_URL=$1
API_KEY=$2

if [ -z "$PANEL_URL" ] || [ -z "$API_KEY" ]; then
    echo "❌ Gunakan format: bash auto-import-eggs.sh <PANEL_URL> <ADMIN_API_KEY>"
    exit 1
fi

echo "=== [1/5] Deteksi file eggs ==="
EGG_FILES=$(find /var/lib/pterodactyl/eggs -name "*.json")

if [ -z "$EGG_FILES" ]; then
    echo "❌ Tidak ada file egg JSON ditemukan di /var/lib/pterodactyl/eggs"
    exit 1
fi

echo "=== [2/5] Upload eggs ke panel ==="
for FILE in $EGG_FILES; do
    GAME=$(basename "$FILE")
    echo "📦 Mengimpor $GAME ..."
    curl -s -X POST "$PANEL_URL/api/application/nests/import" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: multipart/form-data" \
        -F "file=@$FILE" > /tmp/ptero_import.log

    if grep -q '"id":' /tmp/ptero_import.log; then
        echo "✅ $GAME berhasil diimport!"
    else
        echo "⚠️ Gagal import $GAME (cek /tmp/ptero_import.log)"
    fi
done

echo "=== [3/5] Sinkronisasi selesai ==="
echo "Cek di Panel → Nests → Eggs (semua game sudah masuk)"