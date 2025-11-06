#!/bin/bash
# =====================================================
# INSTALL NETDATA MONITORING (Ubuntu 22.04)
# =====================================================

echo "=== [1/3] Update system ==="
sudo apt update -y

echo "=== [2/3] Install Netdata ==="
bash <(curl -Ss https://my-netdata.io/kickstart.sh) --disable-telemetry

echo "=== [3/3] Configure Firewall & Service ==="
sudo systemctl enable netdata
sudo systemctl start netdata

sudo ufw allow 19999

echo ""
echo "🎉 Netdata berhasil diinstall!"
echo "Akses di: http://<ip-vm-kamu>:19999"
echo "Atau via Cloudflare Tunnel:"
echo "sudo cloudflared tunnel --url http://localhost:19999"