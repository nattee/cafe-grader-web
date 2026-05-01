# Cafe-Grader Installation Guide

This guide is derived from the official wiki and outlines the installation steps for Ubuntu 22.04.

## 1. Installation Steps for a Single Server

### Step 1: Install Required Packages
Update your system and install necessary system dependencies and programming language compilers.
```bash
sudo apt update && sudo apt upgrade
sudo apt install apache2 apache2-dev mysql-server git software-properties-common libmysqlclient-dev libcap-dev apt-transport-https postgresql postgresql-server-dev-all unzip
sudo apt install ghc g++ openjdk-18-jdk fpc php-cli php-readline golang-go cargo python3-venv
```

### Step 2: Install Ruby via rbenv
```bash
sudo apt update
sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libncurses5-dev libffi-dev libgdbm-dev
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc
rbenv install 3.4.4
rbenv global 3.4.4
```

### Step 3: Prepare the Database
Login to MySQL and setup the required databases (`grader` and `grader_queue`) and a user.
```bash
sudo mysql -u root
```
Inside the MySQL prompt:
```sql
CREATE DATABASE grader;
CREATE DATABASE grader_queue;
DROP USER IF EXISTS grader_user@localhost;
CREATE USER grader_user@localhost IDENTIFIED BY 'grader_pass';
GRANT ALL PRIVILEGES ON `grader%`.* TO grader_user@localhost;
FLUSH PRIVILEGES;
EXIT;
```

### Step 4: Install `ioi/isolate` (Sandboxing)
Install dependencies and build the sandbox tool.
```bash
sudo apt install libcap-dev libsystemd-dev
git clone https://github.com/ioi/isolate.git
cd isolate
make isolate
sudo make install
```
**Kernel Configuration:** 
You must turn off the system swap space and edit your GRUB configuration to enable memory cgroups.
```bash
sudo swapoff -a
# Edit /etc/fstab and comment out the swap partition line
sudo vi /etc/default/grub
# Add cgroup_enable=memory to GRUB_CMDLINE_LINUX_DEFAULT
sudo update-grub
sudo reboot
```

### Step 5: Install and Configure Cafe-Grader
Create the base directory and clone the app:
```bash
mkdir -p ~/cafe_grader
cd ~/cafe_grader
git clone https://github.com/cafe-grader-team/cafe-grader-web.git web
cd web
gem install bundler
bundle install
```

**Crucial: Initialize Configuration Files**
Rails requires `config/application.rb` to boot. Copy the sample files:
```bash
cp config/application.rb.SAMPLE config/application.rb
cp config/database.yml.SAMPLE config/database.yml
cp config/llm.yml.SAMPLE config/llm.yml
cp config/worker.yml.SAMPLE config/worker.yml
```

### Step 6: Setup Initial App Data
Before setting up the data, ensure your `config/database.yml` matches the user you created in Step 3.

**Admin Credentials Setup:**
By default, the username is `root`. You should securely configure the initial password before running the setup commands:

```bash
export GRADER_ADMIN_PASSWORD='your_secure_password_here'

# Setup master key (requires EDITOR env var)
export EDITOR=nano
bundle exec rails credentials:edit

# Setup databases
bundle exec rails db:setup DISABLE_DATABASE_ENVIRONMENT_CHECK=1 RAILS_ENV=production
bundle exec rails db:seed RAILS_ENV=production

# Compile assets
bundle exec rails dartsass:build RAILS_ENV=production
bundle exec rails assets:precompile RAILS_ENV=production
```

### Step 7: Start Background Processes
Start the background queue and the grader workers:
```bash
rails solid_queue:start &
RAILS_ENV=production rails r "Grader.restart(4)"
```

### Step 8: Deploy with Apache + Phusion Passenger
Follow standard Phusion Passenger deployment instructions for Apache to point the `DocumentRoot` to `~/cafe_grader/web/public`.

---

## 2. Setting up on 3 Servers (1 Web/DB + 2 Grader Workers)

When deploying at scale, splitting the workload is recommended. Here is how to configure a 3-server setup:

### Server 1: Web and Database Node
This server will handle HTTP requests and the MySQL database. It does **not** evaluate code.

1. **Install Web/DB Packages**:
   ```bash
   sudo apt update && sudo apt upgrade
   sudo apt install apache2 apache2-dev mysql-server git software-properties-common libmysqlclient-dev libcap-dev apt-transport-https postgresql postgresql-server-dev-all unzip
   ```

2. **Install Ruby via rbenv**:
   ```bash
   sudo apt update
   sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libncurses5-dev libffi-dev libgdbm-dev
   curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
   echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
   echo 'eval "$(rbenv init -)"' >> ~/.bashrc
   source ~/.bashrc
   rbenv install 3.4.4
   rbenv global 3.4.4
   gem install bundler
   ```

3. **Configure MySQL Network & Databases**: 
   Edit `/etc/mysql/mysql.conf.d/mysqld.cnf` and change `bind-address` to `0.0.0.0` to allow remote connections. Then setup the remote database user:
   ```bash
   sudo mysql -u root
   ```
   ```sql
   CREATE DATABASE grader;
   CREATE DATABASE grader_queue;
   CREATE USER grader_user@'%' IDENTIFIED BY 'grader_pass';
   GRANT ALL PRIVILEGES ON grader.* TO grader_user@'%';
   GRANT ALL PRIVILEGES ON grader_queue.* TO grader_user@'%';
   FLUSH PRIVILEGES;
   EXIT;
   ```
   *Note: Ensure your firewall allows port 3306 from the Worker IPs.*

4. **Install Cafe-Grader Web App**: 
   Clone the repository, compile assets, and configure `database.yml` to use `localhost`.
   ```bash
   mkdir -p ~/cafe_grader && cd ~/cafe_grader
   git clone https://github.com/cafe-grader-team/cafe-grader-web.git web
   cd web
   bundle install
   bundle exec rails credentials:edit
   bundle exec rails db:setup DISABLE_DATABASE_ENVIRONMENT_CHECK=1 RAILS_ENV=production
   bundle exec rails db:seed RAILS_ENV=production
   bundle exec rails dartsass:build RAILS_ENV=production
   bundle exec rails assets:precompile RAILS_ENV=production
   ```

5. **Start Web Server & Solid Queue**: 
   ```bash
   rails solid_queue:start &
   # Then setup Apache/Passenger. Do not start Grader processes here.
   ```

### Server 2 & 3: Grader Worker Nodes
These servers will fetch jobs from the database and compile/run student code securely.

1. **Install Compilers & Ruby**: 
   You do not need Apache or Node.js on these servers.
   ```bash
   sudo apt update && sudo apt upgrade
   sudo apt install git software-properties-common libmysqlclient-dev libcap-dev libsystemd-dev
   sudo apt install ghc g++ openjdk-18-jdk fpc php-cli php-readline golang-go cargo python3-venv
   sudo apt install -y curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libncurses5-dev libffi-dev libgdbm-dev
   curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
   echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
   echo 'eval "$(rbenv init -)"' >> ~/.bashrc
   source ~/.bashrc
   rbenv install 3.4.4
   rbenv global 3.4.4
   gem install bundler
   ```

2. **Install `ioi/isolate`**: Follow the strict kernel guidelines to disable swap and configure cgroups.
   ```bash
   git clone https://github.com/ioi/isolate.git
   cd isolate && make isolate && sudo make install
   sudo swapoff -a
   # Edit /etc/fstab and comment out the swap partition line
   # Edit /etc/default/grub, add cgroup_enable=memory to GRUB_CMDLINE_LINUX_DEFAULT
   sudo update-grub
   sudo reboot
   ```

3. **Install Cafe-Grader App & Connect to DB**: 
   ```bash
   mkdir -p ~/cafe_grader && cd ~/cafe_grader
   git clone https://github.com/cafe-grader-team/cafe-grader-web.git web
   cd web
   bundle install
   ```
   *CRITICAL: Edit `config/database.yml` on these worker nodes to point to **Server 1's IP address** instead of localhost.*

4. **Start Grader Workers**: Run the grader process daemon. We recommend using `Number of CPU Cores - 2`.
   ```bash
   cd ~/cafe_grader/web
   RAILS_ENV=production rails r "Grader.restart(4)" # Adjust '4' based on CPU
   whenever --update-crontab
   ```

By using this 3-server architecture, heavy compilation and infinite-loop code executions on the worker nodes will never impact the performance or responsiveness of the web interface and database.
