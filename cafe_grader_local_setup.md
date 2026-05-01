# Cafe-Grader Local Setup & Testing

Testing and running the application locally without deploying it to a full production server is straightforward. You can start all development services simultaneously using the provided `Procfile.dev`.

## 1. Quick Setup Script (Recommended)

The easiest way to set up the development environment is to use the provided setup script. The script automatically initializes required configuration files from their `.SAMPLE` templates to prevent boot errors, and installs all prerequisites.

**Run this from your `cafe-grader-web` project directory**:

```bash
./setup_local_wsl.sh
```

This script will:
- Install all system dependencies (MySQL, etc.)
- Install rbenv and Ruby 3.4.4
- Install Ruby gems
- Start MySQL and prepare the database

After running the script, complete the manual steps it outputs (credentials, database config, seeds).

## 2. Manual Setup (Alternative)

If you prefer to set up manually instead of using the script, follow these steps.

### Prerequisites Installation (Ubuntu/WSL)
If you are running locally on Ubuntu (or Windows Subsystem for Linux), you need to install the core dependencies first:

1. **System Packages & MySQL**:
   ```bash
   sudo apt update
   sudo apt install -y mysql-server libmysqlclient-dev git curl unzip libpq-dev
   ```
2. **Ruby (via rbenv)**:
   ```bash
   sudo apt update
   sudo apt install -y git curl libssl-dev libreadline-dev zlib1g-dev autoconf bison build-essential libyaml-dev libncurses5-dev libffi-dev libgdbm-dev
   
   curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
   
   # Add rbenv to your PATH in your shell configuration profile (e.g., ~/.bashrc):
   echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
   echo 'eval "$(rbenv init -)"' >> ~/.bashrc
   source ~/.bashrc
   
   rbenv install 3.4.4
   rbenv global 3.4.4
   gem install bundler
   ```

### Setup Local Database
1. **Install Ruby Gems**:
   ```bash
   bundle install
   ```
2. First, ensure MySQL is running locally:
   ```bash
   sudo service mysql start
   ```
3. Make sure your local database credentials (username/password) match those defined in `config/database.yml`, then run:
   ```bash
   bin/rails db:setup
   ```
   *This command creates the databases (like `grader` and `grader_queue`), loads the schema, and initializes them with seed data.*

## 3. Start the Dev Server
Open a terminal in the root folder and run:
```bash
bin/dev
```

This command uses Foreman (or similar) to concurrently start:
- The Puma web server on port `3000` (accessible at `http://localhost:3000`).
- The CSS watcher (`bundle exec rails dartsass:watch`) to automatically compile SCSS on changes.
- The background job queue (`bin/rails solid_queue:start`).

If you wish to run automated tests:
- **All tests**: `bin/rails test`
- **System tests** (UI tests): `bin/rails test:system`
- **API Specs**: `bundle exec rspec spec/requests/api/v1/`

## 4. Web App vs. Grader Worker Testing (WSL Limitation)
*Important Note:* The core grader sandboxing tool (`ioi/isolate`) relies on strict Linux kernel features (cgroups) and **cannot easily run on WSL2** without compiling a custom WSL kernel. 
Because of this, local development is usually split:
1. **Web App & UI Testing**: You can run the web server, database, and background queues perfectly inside WSL. This allows you to build features, manage problems, and test the UI.
2. **Actual Code Grading**: To test the actual compilation and execution of student code, it is highly recommended to use a full Ubuntu Virtual Machine (e.g., VirtualBox, VMware) or a dedicated staging server rather than WSL.
