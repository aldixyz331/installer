#!/bin/bash
# =====================================================
# INSTALL GRAFANA + NETDATA EXPORTER
# =====================================================

echo "=== [1/5] Install dependencies ==="
sudo apt update -y
sudo apt install -y apt-transport-https software-properties-common wget curl

echo "=== [2/5] Tambah repo Grafana ==="
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt update -y
sudo apt install -y grafana

echo "=== [3/5] Enable service ==="
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "=== [4/5] Install Netdata plugin for Grafana ==="
# Netdata sudah expose metrics di port 19999
# Grafana bisa ambil data via JSON datasource

cat <<EOF | sudo tee /etc/grafana/provisioning/datasources/netdata.yml
apiVersion: 1
datasources:
  - name: Netdata
    type: prometheus
    url: http://localhost:19999/api/v1/allmetrics?format=prometheus
    access: proxy
    isDefault: true
EOF

echo "=== [5/5] Restart Grafana ==="
sudo systemctl restart grafana-server

echo ""
echo "🎨 Grafana terpasang!"
echo "Login: http://<ip-vm-kamu>:3000"
echo "User: admin | Pass: admin"
echo ""
echo "➡️ Setelah login, buka menu Dashboards → Import"
echo "Gunakan ID Dashboard: 1860 (Netdata Full)"