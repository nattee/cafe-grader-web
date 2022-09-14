source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.2'

#rails
gem 'rails', '~>7.0'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

gem 'activerecord-session_store'
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
gem 'rails-controller-testing'
#for dumping database into yaml
gem 'yaml_db'


#------------- assset pipeline -----------------
# Gems used only for assets and not required
# in production environments by default.
#sass-rails is depricated
#gem 'sass-rails'
gem 'sassc-rails'
gem 'coffee-rails'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer', :platforms => :ruby

gem 'uglifier'

gem 'haml'
gem 'haml-rails'

# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
#gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'


#in-place editor
gem 'best_in_place', git: "https://github.com/mmotherwell/best_in_place"

# jquery addition
#gem 'jquery-rails'
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
#gem 'momentjs-rails', '>= 2.9.0'
#gem 'rails_bootstrap_sortable'
#gem 'bootstrap-datepicker-rails'
#gem 'bootstrap3-datetimepicker-rails', '~> 4.17.47'
#gem 'jquery-datatables-rails'

#----------- user interface -----------------
gem 'simple_form'
#select 2
gem 'select2-rails'
#ace editor
gem 'ace-rails-ap'
#paginator
#gem 'will_paginate', '~> 3.0.7'

gem 'mail'
gem 'rdiscount'
gem 'dynamic_form'
gem 'in_place_editing'
#gem 'verification', :git => 'https://github.com/sikachu/verification.git'


#---------------- testiing -----------------------
gem 'minitest-reporters'

#---------------- for console --------------------
gem 'fuzzy-string-match'


group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'debug', platforms: [:mri, :mingw, :x64_mingw]
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


gem "importmap-rails", "~> 1.1"
