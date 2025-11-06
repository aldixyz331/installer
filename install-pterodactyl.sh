#!/bin/bash
# =====================================================
#  Auto Install Pterodactyl Panel + Wings (Ubuntu 22.04)
#  by ChatGPT GPT-5 (for learning/home server)
# =====================================================

echo "=== [1/8] Update & install dependencies ==="
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y curl wget unzip tar git nginx mariadb-server redis-server \
 php8.1 php8.1-{cli,common,gd,mysql,mbstring,bcmath,xml,curl,zip,fpm,intl} \
 composer certbot cloudflared

echo "=== [2/8] Setup MariaDB Database ==="
sudo systemctl enable mariadb
sudo systemctl start mariadb
sudo mysql -e "CREATE DATABASE panel;"
sudo mysql -e "CREATE USER 'ptero'@'127.0.0.1' IDENTIFIED BY 'ptero123';"
sudo mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'ptero'@'127.0.0.1';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "=== [3/8] Install Pterodactyl Panel ==="
cd /var/www
sudo mkdir pterodactyl && cd pterodactyl
sudo curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
sudo tar -xzvf panel.tar.gz && rm panel.tar.gz
sudo composer install --no-dev --optimize-autoloader
sudo cp .env.example .env

sudo php artisan key:generate --force
sudo chown -R www-data:www-data /var/www/pterodactyl/*
sudo chmod -R 755 storage/* bootstrap/cache/

# Setup environment
sudo sed -i 's|DB_DATABASE=.*|DB_DATABASE=panel|' .env
sudo sed -i 's|DB_USERNAME=.*|DB_USERNAME=ptero|' .env
sudo sed -i 's|DB_PASSWORD=.*|DB_PASSWORD=ptero123|' .env

echo "=== [4/8] Setup Nginx ==="
cat <<EOF | sudo tee /etc/nginx/sites-available/pterodactyl.conf
server {
    listen 80;
    server_name _;
    root /var/www/pterodactyl/public;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

echo "=== [5/8] Setup Cloudflare Tunnel (gratis) ==="
sudo nohup cloudflared tunnel --url http://localhost:80 > /root/cloudflare.log 2>&1 &
sleep 5
echo "🔗 Akses URL panel kamu di:"
grep -o "https://.*trycloudflare.com" /root/cloudflare.log

echo "=== [6/8] Install Wings (daemon) ==="
curl -Lo /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
chmod +x /usr/local/bin/wings

mkdir -p /etc/pterodactyl
cat <<EOF >/etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wings

echo "=== [7/8] Final permission & firewall ==="
sudo chown -R www-data:www-data /var/www/pterodactyl
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

echo "=== [8/8] Done! ==="
echo ""
echo "🎉 Pterodactyl Panel berhasil diinstall!"
echo "-------------------------------------------------"
grep -o "https://.*trycloudflare.com" /root/cloudflare.log
echo "-------------------------------------------------"
echo "📍 Database: panel / ptero / ptero123"
echo "📍 Web root: /var/www/pterodactyl"
echo "📍 Wings service: systemctl start wings"
echo "-------------------------------------------------"