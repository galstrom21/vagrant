#!/usr/bin/env bash

set -xe

# Create Nautobot Database
echo "INSTALL | Create nautobot database"
DB_PASSWD="secrete"
sudo mysql -e "CREATE DATABASE IF NOT EXISTS nautobot;"
echo "INSTALL | Create nautobot user"
sudo mysql -e "CREATE USER IF NOT EXISTS'nautobot'@'localhost' IDENTIFIED BY '${DB_PASSWD}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON nautobot.* to 'nautobot'@'localhost';"
