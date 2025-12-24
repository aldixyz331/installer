#!/bin/bash

# Update dan install dependensi dasar
apt update && apt upgrade -y
apt install -y curl wget unzip tar git MariaDB-server MariaDB-client npm

# Install Node.js
curl -sL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Install PHP benar-benar
curl -sSL https://packages.sury.org/php/apt.gpg | apt-key add -
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
apt update
apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-mysql php8.1-xml php8.1-mbstring php8.1-curl php8.1-zip php8.1-gd

# Install Redis
apt install -y redis-server

# Install Nginx
apt install -y nginx

# Instalasi MySQL
mysql_secure_installation <<EOF
y
y
y
y
y
EOF

# Buat database dan user untuk Pterodactyl
mysql <<EOF
CREATE DATABASE pterodactyl;
CREATE USER 'pterodactyl_user'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON pterodactyl.* TO 'pterodactyl_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# Buat direktori dan download Pterodactyl
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

# Download Pterodactyl Panel
wget https://github.com/pterodactyl/panel/releases/download/v1.8.0/panel.png
wget https://github.com/pterodactyl/panel/releases/download/v1.8.0/panel.zip

# Ekstrak file zip
unzip panel.zip -d /var/www/pterodactyl
chown -R www-data:www-data /var/www/pterodactyl

# Setup konfigurasi
php /var/www/pterodactyl/artisan config:setup
php /var/www/pterodactyl/artisan migrate --seed --force
php /var/www/pterodactyl/artisan key:generate
php /var/www/pterodactyl/artisan uploads:sync

# Buat konfigurasi Nginx untuk Pterodactyl
cat <<EOF > /etc/nginx/sites-available/pterodactyl
server {
    listen 8000;
    server_name localhost;

    root /var/www/pterodactyl/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_split_path_info ^(.+\\.php)(/.*)\$;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param PATH_TRANSLATED \$document_root\$fastcgi_path_info;
    }

    location ~ /\\.ht {
        deny all;
    }
}
EOF

# Habilitasi site Nginx
ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
systemctl restart nginx

# Buat direktori untuk Wings
mkdir -p /var/www/wings

# Download dan instal Wings
wget https://github.com/pterodactyl/wings/releases/download/v1.8.0/wings.png
wget https://github.com/pterodactyl/wings/releases/download/v1.8.0/wings.zip

# Ekstrak file zip
unzip wings.zip -d /var/www/wings
chown -R www-data:www-data /var/www/wings

# Buat service Wings
cat <<EOF > /etc/systemd/system/wings.service
[Unit]
Description=Pterodactyl Wings Daemon
After=syslog.target network-online.target

[Service]
Type=simple
User=www-data
ExecStart=/usr/bin/node /var/www/wings/wings.js
WorkingDirectory=/var/www/wings
Restart=always
RestartSec=5
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF

# Enabled dan start service Wings
systemctl enable wings
systemctl start wings

echo "Instalasi Pterodactyl Panel dan Wings selesai. Anda dapat mengakses panel melalui http://localhost"
