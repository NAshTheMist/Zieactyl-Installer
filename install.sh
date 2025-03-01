#!/bin/bash

# CtrlPanel Auto Installer - Ubuntu 22.04
# Supports IPv4 or Domain
# Uses Nginx as the web server
# Allows users to set their own MySQL and Admin credentials

echo "========================================="
echo "      CtrlPanel Auto Installer           "
echo "========================================="
read -p "Enter your VPS IPv4 Address or Domain: " SERVER_NAME
echo "Do you want to install SSL (HTTPS)? (yes/no)"
read -r SSL_CHOICE

# User sets MySQL credentials
read -p "Enter MySQL Database Name: " MYSQL_DB
read -p "Enter MySQL Username: " MYSQL_USER
read -s -p "Enter MySQL Password: " MYSQL_PASS
echo ""

# User sets CtrlPanel admin credentials
read -p "Enter Admin Username: " ADMIN_USER
read -s -p "Enter Admin Password: " ADMIN_PASS
echo ""

echo "Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y curl tar unzip git redis-server ffmpeg \
  python3 python3-pip python3-dev python3-venv \
  mariadb-server mariadb-client nginx \
  php php-cli php-mbstring php-bcmath php-xml \
  php-curl php-zip php-gd php-mysql php-tokenizer

# If SSL is selected, install Certbot
if [[ "$SSL_CHOICE" == "yes" ]]; then
    apt install -y certbot python3-certbot-nginx
fi

# Set up MariaDB
echo "Configuring MySQL..."
mysql -u root -e "CREATE DATABASE $MYSQL_DB;"
mysql -u root -e "CREATE USER '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASS';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $MYSQL_DB.* TO '$MYSQL_USER'@'localhost' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"

# Install CtrlPanel
echo "Installing CtrlPanel..."
cd /var/www
git clone https://github.com/Ctrlpanel-gg/panel.git ctrlpanel
cd ctrlpanel
chmod +x install.sh
./install.sh

# Configure Nginx
echo "Setting up Nginx for CtrlPanel..."
cat > /etc/nginx/sites-available/ctrlpanel <<EOF
server {
    listen 80;
    server_name $SERVER_NAME;

    root /var/www/ctrlpanel/public;
    index index.php index.html index.htm;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/ctrlpanel /etc/nginx/sites-enabled/
systemctl restart nginx

# Enable SSL if chosen
if [[ "$SSL_CHOICE" == "yes" ]]; then
    echo "Enabling SSL..."
    certbot --nginx -d $SERVER_NAME --non-interactive --agree-tos -m your@email.com
fi

# Finalizing
cd /var/www/ctrlpanel
php artisan migrate --seed --force
php artisan queue:restart
chown -R www-data:www-data /var/www/ctrlpanel
chmod -R 755 /var/www/ctrlpanel
systemctl restart nginx

# Create Admin User
php artisan ctrlpanel:admin:create --username="$ADMIN_USER" --password="$ADMIN_PASS"

echo "========================================="
echo " CtrlPanel installation is complete!"
echo " Access it via: http://$SERVER_NAME"
[[ "$SSL_CHOICE" == "yes" ]] && echo " SSL Enabled: https://$SERVER_NAME"
echo " MySQL Database: $MYSQL_DB"
echo " MySQL Username: $MYSQL_USER"
echo " MySQL Password: (hidden for security)"
echo " Admin Username: $ADMIN_USER"
echo " Admin Password: (hidden for security)"
echo ""
echo " Created by SuperFafnir"
echo "========================================="
