#!/usr/bin/env bash
set -euo pipefail

APP_NAME="cicdtest"
APP_DIR="/var/www/cicdtest"
SERVICE_FILE="/etc/systemd/system/cicdtest.service"
NGINX_SITE="/etc/nginx/sites-available/cicdtest"

sudo apt-get update
sudo apt-get install -y nginx unzip apt-transport-https

wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
sudo dpkg -i /tmp/packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y dotnet-runtime-9.0

sudo mkdir -p "$APP_DIR"
sudo chown -R www-data:www-data "$APP_DIR"

sudo cp ./deploy/systemd/cicdtest.service "$SERVICE_FILE"
sudo systemctl daemon-reload
sudo systemctl enable "$APP_NAME"

sudo cp ./deploy/nginx/cicdtest.conf "$NGINX_SITE"
sudo ln -sf "$NGINX_SITE" /etc/nginx/sites-enabled/cicdtest
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
