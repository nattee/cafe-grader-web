#!/bin/bash
# Cafe-Grader Web/DB Server Installation Script (Server 1 of 3)

set -e

echo "Starting Web/DB Node Installation..."

# 1. System updates and packages
sudo apt update && sudo apt upgrade -y
sudo apt install -y apache2 apache2-dev mysql-server git software-properties-common libmysqlclient-dev libcap-dev apt-transport-https nodejs postgresql postgresql-server-dev-all unzip

# 2. RVM and Ruby
echo "Installing RVM and Ruby..."
sudo apt-add-repository -y ppa:rael-gc/rvm
sudo apt update
sudo apt install -y rvm
sudo usermod -a -G rvm $USER
source /etc/profile.d/rvm.sh
rvm install 3.4.4
rvm use 3.4.4 --default

# 3. MySQL Setup for Remote Connections
echo "Setting up MySQL databases and remote user..."
sudo sed -i 's/bind-address.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
sudo service mysql restart

sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS grader;"
sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS grader_queue;"
sudo mysql -u root -e "CREATE USER IF NOT EXISTS grader_user@'%' IDENTIFIED BY 'grader_pass';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON grader.* TO grader_user@'%';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON grader_queue.* TO grader_user@'%';"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

# 4. App Setup
echo "Setting up Cafe-Grader Web App..."
mkdir -p ~/cafe_grader
cd ~/cafe_grader
if [ ! -d "web" ]; then
  git clone https://github.com/cafe-grader-team/cafe-grader-web.git web
fi
cd web
bundle install
sudo corepack enable
corepack prepare yarn@stable --activate
yarn install

echo "--------------------------------------------------------"
echo "Web/DB Node Installation almost complete!"
echo "Please perform the following manual steps:"
echo "--------------------------------------------------------"
echo "1. Run: rails credentials:edit"
echo "2. Edit config/database.yml to use grader_user & grader_pass"
echo "3. Run: rails db:setup DISABLE_DATABASE_ENVIRONMENT_CHECK=1 RAILS_ENV=production"
echo "4. Run: rails db:seed RAILS_ENV=production"
echo "5. Run: rails assets:precompile RAILS_ENV=production"
echo "6. Setup Apache and Passenger."
echo "7. Run: rails solid_queue:start &"
