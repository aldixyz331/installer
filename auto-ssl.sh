#!/bin/bash
# =====================================================
# AUTO SSL SETUP via Cloudflare Tunnel (Let's Encrypt)
# =====================================================

echo "=== [1/4] Install dependencies ==="
sudo apt update -y
sudo apt install -y certbot python3-certbot-nginx

echo "=== [2/4] Menentukan domain Cloudflare Tunnel ==="
CF_DOMAIN=$(grep -o "https://.*trycloudflare.com" /root/cloudflare.log | head -n 1 | sed 's#https://##')
if [ -z "$CF_DOMAIN" ]; then
    echo "❌ Tidak ditemukan domain Cloudflare aktif."
    echo "Pastikan cloudflared sudah jalan di VM kamu."
    exit 1
fi
echo "✅ Domain terdeteksi: $CF_DOMAIN"

echo "=== [3/4] Konfigurasi Nginx ==="
sudo sed -i "s/server_name _;/server_name $CF_DOMAIN;/" /etc/nginx/sites-available/pterodactyl.conf
sudo nginx -t && sudo systemctl reload nginx

echo "=== [4/4] Generate SSL certificate ==="
sudo certbot --nginx -d "$CF_DOMAIN" --agree-tos -m admin@$CF_DOMAIN --no-eff-email --redirect

echo ""
echo "🎉 SSL berhasil diaktifkan!"
echo "Akses panel kamu di: https://$CF_DOMAIN"
echo "Sertifikat otomatis diperbarui setiap 60 hari."