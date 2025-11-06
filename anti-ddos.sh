#!/usr/bin/env bash
# installer-anti-ddos.sh
# For Ubuntu 22.04
# Installs/configures:
# - sysctl tuning (SYN cookies, conntrack)
# - nftables + ipset firewall (basic rules)
# - fail2ban with ipset action
# - Nginx rate-limiting snippet (for Pterodactyl/nginx)
# - Netdata install (monitoring)
#
# RUN AS: sudo bash installer-anti-ddos.sh
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Jalankan script ini sebagai root (sudo)."
  exit 1
fi

echo "=== Installer Anti-DDoS untuk Ubuntu 22.04 ==="
echo

# 1) Get SSH port from user (safe default 22)
read -p "Masukkan port SSH yang sekarang kamu pakai (default 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

# 2) Get list of allowed service ports (comma separated). Provide sensible defaults.
echo
echo "Masukkan daftar port yang ingin di-ALLOW (pisah koma)."
echo "Contoh default untuk Pterodactyl + Proxmox + Minecraft: 80,443,8006,8080,25565,${SSH_PORT}"
read -p "Allowed ports (default shown): " ALLOW_PORTS
if [ -z "$ALLOW_PORTS" ]; then
  ALLOW_PORTS="80,443,8006,8080,25565,${SSH_PORT}"
fi

# Normalize ALLOW_PORTS to array
IFS=',' read -r -a PORTS_ARRAY <<< "$ALLOW_PORTS"

echo
echo "Summary:"
echo " - SSH port: ${SSH_PORT}"
echo " - Allowed ports: ${ALLOW_PORTS}"
read -p "Lanjutkan dan apply konfigurasi ini? (y/N) " CONF
CONF=${CONF:-N}
if [[ ! "$CONF" =~ ^[Yy]$ ]]; then
  echo "Batal. Tidak ada perubahan dibuat."
  exit 0
fi

echo
echo "=== Mulai instalasi paket dasar ==="
apt update
DEPS="nftables ipset fail2ban curl ca-certificates gnupg lsb-release nginx"
apt install -y $DEPS

# 3) sysctl tuning (safe values)
echo "=== Apply sysctl tuning (anti-DDoS basics) ==="
cat > /etc/sysctl.d/10-ddos-sysctl.conf <<'SYSCTL'
# SYN cookies + backlog
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 4096
# Reduce timeouts and keepalive
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 60
# Conntrack limits
net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_tcp_timeout_established = 600
# ICMP tweaks
net.ipv4.icmp_echo_ignore_broadcasts = 1
SYSCTL
sysctl --system

# 4) nftables + ipset configuration (creates basic table)
echo "=== Konfigurasi nftables + ipset ==="

# create ipset 'blacklist' if not exists
ipset list blacklist >/dev/null 2>&1 || ipset create blacklist hash:ip family inet hashsize 1024 maxelem 65536

# build nft ruleset
cat > /root/ddos-nft-rules.nft <<'NFT'
table inet filter {
  set blacklist {
    type ipv4_addr
    flags dynamic
    timeout 0
  }

  chain input {
    type filter hook input priority 0; policy drop;
    # established/related
    ct state established,related accept
    # loopback
    iif "lo" accept
    # drop blacklisted
    ip saddr @blacklist drop
    # drop invalid conn
    ct state invalid drop
    # icmp rate-limited
    icmp type echo-request limit rate 10/second accept
    # allow SSH will be inserted dynamically below
    # allow other service ports will be inserted dynamically below
    # default drop for others
  }

  chain forward { type filter hook forward priority 0; policy accept; }
  chain output { type filter hook output priority 0; policy accept; }
}
NFT

# write nft file and then add dynamic allow rules for ports
nft -f /root/ddos-nft-rules.nft

# Add SSH and service ports to nft (use limit on new connections)
for p in "${PORTS_ARRAY[@]}"; do
  p_trim=$(echo "$p" | tr -d ' ')
  if [[ "$p_trim" =~ ^[0-9]+$ ]]; then
    echo "Allow TCP port $p_trim (new connections limited)..."
    nft add rule inet filter input tcp dport $p_trim ct state new limit rate 60/second accept || true
  fi
done

# ensure nftables service enabled
systemctl enable --now nftables

echo "nftables configured. Current rules:"
nft list ruleset | sed -n '1,200p'

# 5) fail2ban setup + ipset action
echo "=== Konfigurasi fail2ban (dengan ipset action) ==="
apt install -y fail2ban

# create action file for ipset blacklist
cat > /etc/fail2ban/action.d/ipset-blacklist.conf <<'IPSETACT'
[Definition]
actionstart = /usr/sbin/ipset create blacklist hash:ip -exist
actionstop = /usr/sbin/ipset destroy blacklist -exist
actioncheck = /usr/sbin/ipset list blacklist >/dev/null 2>&1 || /usr/sbin/ipset create blacklist hash:ip -exist
actionban = /usr/sbin/ipset add blacklist <ip> -exist
actionunban = /usr/sbin/ipset del blacklist <ip> -exist
IPSETACT

# create jail.local with some defaults
cat > /etc/fail2ban/jail.d/zz-ddos-jails.local <<'JAILS'
[DEFAULT]
bantime = 86400
findtime = 600
maxretry = 5
banaction = ipset-blacklist

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 5
JAILS

systemctl restart fail2ban
systemctl enable fail2ban

echo "fail2ban aktif. Cek status: sudo systemctl status fail2ban"

# 6) Nginx rate limit snippet (for Pterodactyl)
echo "=== Menambahkan snippet Nginx untuk rate limiting ==="
NGINX_SNIPPET="/etc/nginx/snippets/ratelimit.conf"
mkdir -p /etc/nginx/snippets
cat > "$NGINX_SNIPPET" <<'NGINXCONF'
# rate limit snippet
limit_conn_zone $binary_remote_addr zone=addr:10m;
limit_req_zone $binary_remote_addr zone=req:10m rate=10r/s;

# block simple bad bots
map $http_user_agent $bad_ua {
    default 0;
    "~*(sqlmap|nikto|masscan|nmap|curl|wget)" 1;
}
NGINXCONF

# tell user how to include snippet
echo
echo "Tambahkan baris ini di dalam server { } block site Pterodactyl (/etc/nginx/sites-available/pterodactyl.conf):"
echo "    include snippets/ratelimit.conf;"
echo "    limit_conn addr 10;"
echo "    limit_req zone=req burst=20 nodelay;"
echo
echo "Script tidak mengubah file site Nginx otomatis (biar aman). Setelah kamu include, reload nginx."

# 7) Install Netdata (monitoring)
echo "=== Install Netdata (monitoring) ==="
bash <(curl -Ss https://my-netdata.io/kickstart.sh) --disable-telemetry || echo "Netdata install mungkin gagal, cek manual."

# open firewall for netdata if needed (port 19999)
if ! nft list ruleset | grep -q "19999"; then
  echo "Memungkinkan port 19999 (Netdata) di nftables..."
  nft add rule inet filter input tcp dport 19999 ct state new limit rate 60/second accept || true
fi

# 8) Safety reminder & instructions to add IP to whitelist if locked out
echo
echo "=== Selesai pemasangan dasar. Hal yang perlu kamu cek SELANJUTNYA: ==="
echo "1) Pastikan SSH tetap bisa diakses melalui port ${SSH_PORT}."
echo "   Jika ter-block, akses console fisik / Proxmox console untuk membatalkan."
echo "2) Tambahkan include snippets/ratelimit.conf di konfigurasi nginx site Pterodactyl, lalu: sudo nginx -t && sudo systemctl reload nginx"
echo "3) Untuk melihat blacklist saat ini: sudo ipset list blacklist"
echo "   Untuk menambah IP whitelist (jika perlu): sudo ipset add blacklist <ip> (atau hapus)"
echo "4) Cek netdata: http://<ip-vm>:19999 (atau via Cloudflare Tunnel)"
echo
echo "Rekomendasi lanjutan:"
echo " - Pasang Cloudflare (free) untuk web panel."
echo " - Untuk game UDP publik, pertimbangkan host di provider dengan anti-DDoS atau gunakan relay."
echo
echo "Installer selesai. Reboot direkomendasikan: sudo reboot"