#!/bin/bash
# ================================================
#  AUTO SETUP PROXMOX + VM + CLOUDFLARE TUNNEL
#  by ChatGPT GPT-5 (untuk belajar)
# ================================================

echo "=== [1/5] Mengatur Jaringan Proxmox (vmbr0) ==="

cat <<EOF >/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
    bridge-ports eth0
    bridge-stp off
    bridge-fd 0
EOF

systemctl restart networking
echo "✅ vmbr0 selesai dikonfigurasi."

# ================================================
echo "=== [2/5] Download Ubuntu Server ISO ==="
cd /var/lib/vz/template/iso || mkdir -p /var/lib/vz/template/iso && cd /var/lib/vz/template/iso
wget -q --show-progress https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso
echo "✅ ISO Ubuntu 22.04 berhasil diunduh."

# ================================================
echo "=== [3/5] Membuat VM Baru (ID: 100) ==="
qm create 100 --name ubuntu-vm --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0 --cdrom /var/lib/vz/template/iso/ubuntu-22.04.5-live-server-amd64.iso --scsihw virtio-scsi-pci --scsi0 local-lvm:10 --boot order=scsi0
echo "✅ VM (ID 100) berhasil dibuat."

# ================================================
echo "=== [4/5] Menyiapkan Cloudflare Tunnel ==="
apt update -y && apt install cloudflared -y
nohup cloudflared tunnel --url http://192.168.1.101:80 > /root/cloudflare.log 2>&1 &
echo "✅ Cloudflare Tunnel aktif (gunakan URL trycloudflare)."

# ================================================
echo "=== [5/5] Info Akhir ==="
echo ""
echo "✅ Instalasi selesai!"
echo "-------------------------------------------------"
echo "Proxmox Web UI   : https://192.168.1.10:8006"
echo "Login            : root / (password saat install)"
echo "VM ID            : 100"
echo "Cloudflare URL   : Cek log di /root/cloudflare.log"
echo "-------------------------------------------------"
echo "💡 Jalankan VM lewat Web UI, lalu install Ubuntu seperti biasa."