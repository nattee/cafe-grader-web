#!/bin/bash
# Cafe-Grader Local Web Development Setup Script (WSL/Ubuntu)
# This sets up the environment needed to run the web interface locally via `bin/dev`.
# It does NOT install Apache or configure production remote databases.
#
# IMPORTANT: Run this script from your existing cafe-grader-web project directory.
# Do NOT clone a separate copy - use your local codebase.

set -e

echo "Starting Local Web Environment Setup for WSL/Ubuntu..."

# 1. System updates and packages
echo "Installing system dependencies..."
sudo apt update
sudo apt install -y mysql-server libmysqlclient-dev git curl unzip libpq-dev

# 2. rbenv and Ruby
echo "Installing rbenv and Ruby..."

sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libncurses5-dev libffi-dev libgdbm-dev

if [ ! -d "$HOME/.rbenv" ]; then
    curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
fi

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

if ! grep -q 'rbenv init' ~/.bashrc; then
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
fi

echo "Installing Ruby 3.4.4..."
if ! rbenv versions | grep -q 3.4.4; then
    rbenv install 3.4.4
fi

rbenv global 3.4.4
rbenv shell 3.4.4

# Install bundler
gem install bundler

# Verify we're using the correct Ruby
echo "Ruby location: $(which ruby)"
echo "Ruby version: $(ruby --version)"

# 4. App Setup - Run from current directory (do not clone)
echo "Setting up Cafe-Grader Web App..."
cd "$(dirname "$0")"

# Fix Windows line endings (CRLF -> LF) on bin/* scripts
echo "Fixing line endings on bin/* scripts..."
sed -i 's/\r$//' bin/*

# 5. Configuration Setup
echo "Copying sample configuration files..."
# This prevents the LoadError by ensuring application.rb exists
for file in application.rb database.yml llm.yml worker.yml; do
    if [ ! -f "config/$file" ]; then
        echo "Creating config/$file from sample..."
        cp "config/$file.SAMPLE" "config/$file"
    fi
done

echo "Installing Ruby Gems..."
bundle install

echo "Building CSS assets..."
bundle exec rails dartsass:build

echo "Starting MySQL..."
sudo service mysql start

echo "--------------------------------------------------------"
echo "Local Web Environment setup complete!"
echo "Please perform the following manual steps:"
echo "--------------------------------------------------------"
echo "1. Create the MySQL user for the app (run this in your terminal):"
echo "   sudo mysql -e \"DROP USER IF EXISTS 'grader'@'localhost'; CREATE USER 'grader'@'localhost' IDENTIFIED BY 'grader'; GRANT ALL PRIVILEGES ON \\\`grader%\\\`.* TO 'grader'@'localhost'; FLUSH PRIVILEGES;\""
echo ""
echo "2. Run: bundle exec rails credentials:edit"
echo "   (If you get an error, set your editor first: export EDITOR=nano)"
echo ""
echo "3. Run the database setup:"
echo "   bundle exec bin/rails db:setup"
echo "   bundle exec bin/rails db:seed"
echo ""
echo "4. To start the local server, run: bin/dev"
echo ""
echo "NOTE: Always use 'bundle exec' before rails commands."
