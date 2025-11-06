#!/bin/bash
# =====================================================
# AUTO INSTALL GAME EGGS for PTERODACTYL WINGS
# =====================================================
# Tested on Ubuntu 22.04 + Pterodactyl Panel/Wings
# =====================================================

echo "=== [1/6] Update system & dependencies ==="
sudo apt update -y
sudo apt install -y docker.io jq curl unzip git

sudo systemctl enable docker
sudo systemctl start docker

echo "=== [2/6] Download official game eggs ==="
cd /tmp
git clone https://github.com/parkervcp/eggs.git
cd eggs

echo "=== [3/6] Prepare import directory ==="
mkdir -p /var/lib/pterodactyl/eggs
cp -r ./game_eggs/minecraft ./game_eggs/csgo /var/lib/pterodactyl/eggs/ 2>/dev/null || true

echo "=== [4/6] Import eggs ke Panel (manual link) ==="
echo ""
echo "📦 Semua template (egg) sudah siap di folder:"
echo "👉 /var/lib/pterodactyl/eggs/"
echo ""
echo "Silakan login ke Panel Pterodactyl kamu,"
echo "lalu buka menu: **Nests → Import Egg → Upload JSON**"
echo "dan pilih salah satu file JSON dari folder tersebut."
echo ""
echo "Contoh file:"
echo " - Minecraft: /var/lib/pterodactyl/eggs/minecraft/java/egg-minecraft-paper.json"
echo " - CS:GO: /var/lib/pterodactyl/eggs/csgo/egg-counter-strike-global-offensive.json"
echo ""

echo "=== [5/6] Set Wings service to start automatically ==="
sudo systemctl enable wings
sudo systemctl restart wings

echo "=== [6/6] Done! ==="
echo ""
echo "🎮 Eggs Minecraft & CS:GO siap diimport!"
echo "Setelah import, kamu bisa buat server baru dari panel:"
echo "➡️ Create Server → Choose Nest → Pilih Game → Deploy."
echo ""