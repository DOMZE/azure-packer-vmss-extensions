#!/bin/bash

echo "Updating system"
apt-get update && apt-get upgrade -y

echo "Configuring NGINX"
apt-get install nginx jq -y
if [ "$?" -ne "0" ]; then
    echo "Failed to install packages"
    exit 1
fi
rm -rf /var/www/html/*
mv /tmp/artifacts/* /var/www/html

echo "Updating the firewall for HTTP traffic"
ufw allow 'Nginx HTTP'