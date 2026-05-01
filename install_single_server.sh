#!/bin/bash
# Cafe-Grader Single Server Installation Script (Ubuntu 22.04+)
# Note: You should run this as a normal user with sudo privileges, not root directly.

set -e

echo "Starting Cafe-Grader installation for a Single Server..."

# 1. System updates and packages
echo "Installing system dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y apache2 apache2-dev mysql-server git software-properties-common libmysqlclient-dev libcap-dev apt-transport-https nodejs postgresql postgresql-server-dev-all unzip
sudo apt install -y ghc g++ openjdk-18-jdk fpc php-cli php-readline golang-go cargo python3-venv libsystemd-dev

# 2. MySQL Setup
echo "Setting up MySQL databases and user..."
sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS grader;"
sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS grader_queue;"
sudo mysql -u root -e "CREATE USER IF NOT EXISTS grader_user@localhost IDENTIFIED BY 'grader_pass';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON grader.* TO grader_user@localhost;"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON grader_queue.* TO grader_user@localhost;"
sudo mysql -u root -e "FLUSH PRIVILEGES;"

# 3. RVM and Ruby
echo "Installing RVM and Ruby..."
sudo apt-add-repository -y ppa:rael-gc/rvm
sudo apt update
sudo apt install -y rvm
sudo usermod -a -G rvm $USER
# Source RVM directly so we can use it in this script
source /etc/profile.d/rvm.sh
rvm install 3.4.4
rvm use 3.4.4 --default

# 4. ioi/isolate
echo "Installing ioi/isolate..."
git clone https://github.com/ioi/isolate.git /tmp/isolate || true
cd /tmp/isolate
make isolate
sudo make install
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 5. App Setup
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
echo "Installation almost complete! Some manual steps remain:"
echo "--------------------------------------------------------"
echo "1. Run: rails credentials:edit (to create master.key)"
echo "2. Edit config/database.yml to use grader_user & grader_pass"
echo "3. Run: rails db:setup DISABLE_DATABASE_ENVIRONMENT_CHECK=1 RAILS_ENV=production"
echo "4. Run: rails db:seed RAILS_ENV=production"
echo "5. Run: rails assets:precompile RAILS_ENV=production"
echo "6. EDIT /etc/default/grub to add 'cgroup_enable=memory' to GRUB_CMDLINE_LINUX_DEFAULT"
echo "7. Run: sudo update-grub"
echo "8. REBOOT your server to apply kernel memory changes."
echo "9. Start your queues and workers."
