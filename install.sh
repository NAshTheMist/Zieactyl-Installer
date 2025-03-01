#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}CtrlPanel Installer by SuperFafnir${NC}"
echo "1) Install CtrlPanel"
echo "2) Uninstall CtrlPanel"
echo "3) Exit"
read -p "Choose an option: " option

if [ "$option" == "1" ]; then
    echo -e "${GREEN}Installing CtrlPanel...${NC}"
    
    # Update & install dependencies
    apt update && apt install -y nginx mariadb-server php php-fpm php-mysql unzip curl sudo
    
    # Ask for domain or IPv4
    read -p "Enter your domain or IPv4: " DOMAIN

    # Set up Nginx configuration
    cat > /etc/nginx/sites-available/ctrlpanel <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/ctrlpanel;
    index index.php index.html;
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    ln -s /etc/nginx/sites-available/ctrlpanel /etc/nginx/sites-enabled/

    # Reload Nginx
    systemctl restart nginx

    # Set up CtrlPanel files
    mkdir -p /var/www/ctrlpanel
    cd /var/www/ctrlpanel
    wget https://ctrlpanel.gg/latest.zip -O ctrlpanel.zip
    unzip ctrlpanel.zip && rm ctrlpanel.zip
    chown -R www-data:www-data /var/www/ctrlpanel

    # Set up MySQL
    read -p "Enter MySQL root password: " MYSQL_ROOT_PASS
    read -p "Enter CtrlPanel database name: " DB_NAME
    read -p "Enter CtrlPanel database user: " DB_USER
    read -p "Enter CtrlPanel database password: " DB_PASS

    mysql -u root -p$MYSQL_ROOT_PASS -e "CREATE DATABASE $DB_NAME;"
    mysql -u root -p$MYSQL_ROOT_PASS -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    mysql -u root -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    mysql -u root -p$MYSQL_ROOT_PASS -e "FLUSH PRIVILEGES;"

    echo -e "${GREEN}Installation Complete! Visit http://$DOMAIN to continue setup.${NC}"

elif [ "$option" == "2" ]; then
    echo -e "${RED}Uninstalling CtrlPanel...${NC}"

    # Stop & disable services
    systemctl stop nginx mariadb php8.1-fpm
    systemctl disable nginx mariadb php8.1-fpm

    # Remove files
    rm -rf /var/www/ctrlpanel
    rm -f /etc/nginx/sites-available/ctrlpanel
    rm -f /etc/nginx/sites-enabled/ctrlpanel

    # Drop MySQL database & user
    read -p "Enter MySQL root password: " MYSQL_ROOT_PASS
    read -p "Enter CtrlPanel database name: " DB_NAME
    read -p "Enter CtrlPanel database user: " DB_USER

    mysql -u root -p$MYSQL_ROOT_PASS -e "DROP DATABASE $DB_NAME;"
    mysql -u root -p$MYSQL_ROOT_PASS -e "DROP USER '$DB_USER'@'localhost';"
    mysql -u root -p$MYSQL_ROOT_PASS -e "FLUSH PRIVILEGES;"

    # Uninstall packages
    apt remove --purge -y mariadb-server mariadb-client nginx php* redis-server
    apt autoremove -y
    apt clean

    echo -e "${RED}CtrlPanel has been completely removed!${NC}"

elif [ "$option" == "3" ]; then
    echo "Exiting..."
    exit 0

else
    echo -e "${RED}Invalid option!${NC}"
fi
