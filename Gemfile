source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.4"

# rails
gem "rails", "~>8.0.0"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
# gem "sprockets-rails"
gem "propshaft" # Replaces sprockets-rails for serving assets
gem "cssbundling-rails" # Replaces sassc-rails for compiling CSS

gem "puma"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

#---------------- database ---------------------
# the database
gem "mysql2"
# for testing
gem "sqlite3"

# for grader
gem "pg"
# gem 'rails-controller-testing'
# for dumping database into yaml
# gem 'yaml_db'

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# faraday for API call
gem "faraday"


#------------- assset pipeline -----------------
# Gems used only for assets and not required
# in production environments by default.
# sass-rails is depricated
# gem 'sass-rails'
# 2025 remove sprockets and go to propshaft
#  gem 'sassc-rails'
#   gem 'coffee-rails'
# gem 'material_icons'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem 'therubyracer', :platforms => :ruby

# use import map
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"


gem "haml"
gem "haml-rails"

gem "jbuilder"

# jquery addition
# gem 'jquery-rails', '~> 4.6'
# gem 'jquery-ui-rails'
# gem 'jquery-timepicker-addon-rails'
# gem 'jquery-tablesorter'
# gem 'jquery-countdown-rails'

# syntax highlighter
gem "rouge"

#----------- user interface -----------------
# gem 'simple_form', git: 'https://github.com/heartcombo/simple_form', ref: '31fe255'
gem "simple_form"

# ace editor
# gem 'ace-rails-ap' # move to propshaft

gem "mail"
gem "rdiscount"  # markdown
gem "redcarpet"  # new markdown
gem "kramdown"
gem "rainbow"

gem "whenever", require: false

# fix some ???? bugs???
gem "concurrent-ruby", "1.3.4"


group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "web-console", ">= 3.3.0"


  # gem 'listen', '>= 3.0.5', '< 3.2'
  # # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  # gem 'spring'
  # gem 'spring-watcher-listen', '~> 2.0.0'

  # fix some ???? bugs ????
  gem "mutex_m"
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem "capybara"
  gem "selenium-webdriver"
end
