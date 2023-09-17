source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.1'

#rails
gem 'rails', '~>7.0'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

gem 'puma'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

#---------------- database ---------------------
#the database
gem 'mysql2'
#for testing
gem 'sqlite3'
#gem 'rails-controller-testing'
#for dumping database into yaml
#gem 'yaml_db'


#------------- assset pipeline -----------------
# Gems used only for assets and not required
# in production environments by default.
#sass-rails is depricated
#gem 'sass-rails'
gem 'sassc-rails'
gem 'coffee-rails'
gem 'material_icons'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer', :platforms => :ruby

# use import map
gem "importmap-rails", "~> 1.1"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

gem 'haml'
gem 'haml-rails'

gem 'jbuilder'

# jquery addition
gem 'jquery-rails'
#gem 'jquery-ui-rails'
#gem 'jquery-timepicker-addon-rails'
#gem 'jquery-tablesorter'
#gem 'jquery-countdown-rails'

#syntax highlighter
gem 'rouge'

#bootstrap add-ons
#gem 'bootstrap-sass', '~> 3.4.1'
gem 'bootstrap', '~> 5.2'
#gem 'bootstrap-switch-rails'
#gem 'bootstrap-toggle-rails'
#gem 'autoprefixer-rails'
gem 'momentjs-rails'
#gem 'rails_bootstrap_sortable'
#gem 'bootstrap-datepicker-rails'
#gem 'bootstrap3-datetimepicker-rails', '~> 4.17.47'
#gem 'jquery-datatables-rails'

#----------- user interface -----------------
gem 'simple_form', git: 'https://github.com/heartcombo/simple_form', ref: '31fe255'

#ace editor
gem 'ace-rails-ap'

gem 'mail'
gem 'rdiscount'  #markdown
gem 'rainbow'

gem 'whenever', require: false


#---------------- testiing -----------------------
gem 'minitest-reporters'

#---------------- for console --------------------
gem 'fuzzy-string-match'


group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug'
end

group :development do
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"
end

group :test do
  # Adds support for Capybara system testing and selenium driver
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'webdrivers'
end


