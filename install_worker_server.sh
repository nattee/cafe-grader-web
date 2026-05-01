#!/bin/bash
# Cafe-Grader Worker Server Installation Script (Server 2 & 3)

set -e

echo "Starting Worker Node Installation..."

# 1. Compilers and tools
sudo apt update && sudo apt upgrade -y
sudo apt install -y git software-properties-common libmysqlclient-dev libcap-dev libsystemd-dev
sudo apt install -y ghc g++ openjdk-18-jdk fpc php-cli php-readline golang-go cargo python3-venv

# 2. RVM and Ruby
echo "Installing RVM and Ruby..."
sudo apt-add-repository -y ppa:rael-gc/rvm
sudo apt update
sudo apt install -y rvm
sudo usermod -a -G rvm $USER
source /etc/profile.d/rvm.sh
rvm install 3.4.4
rvm use 3.4.4 --default

# 3. ioi/isolate
echo "Installing ioi/isolate..."
git clone https://github.com/ioi/isolate.git /tmp/isolate || true
cd /tmp/isolate
make isolate
sudo make install
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 4. App Setup
echo "Cloning Cafe-Grader App..."
mkdir -p ~/cafe_grader
cd ~/cafe_grader
if [ ! -d "web" ]; then
  git clone https://github.com/cafe-grader-team/cafe-grader-web.git web
fi
cd web
bundle install

echo "--------------------------------------------------------"
echo "Worker Node Installation almost complete!"
echo "Please perform the following manual steps:"
echo "--------------------------------------------------------"
echo "1. Edit config/database.yml to point to Server 1's IP address and credentials."
echo "2. Edit /etc/default/grub to add 'cgroup_enable=memory' to GRUB_CMDLINE_LINUX_DEFAULT"
echo "3. Run: sudo update-grub"
echo "4. Reboot the server."
echo "5. After reboot, navigate to ~/cafe_grader/web and run: RAILS_ENV=production rails r \"Grader.restart(4)\""
