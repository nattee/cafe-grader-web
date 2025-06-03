require_relative "boot"

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CafeGrader
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib)
    config.eager_load_paths << Rails.root.join('lib')

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = "Asia/Bangkok"

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :en

    # ---------------- IMPORTANT ----------------------
    # If we deploy the app into a subdir name "grader", be sure to do "rake assets:precompile RAILS_RELATIVE_URL_ROOT=/grader"
    # moreover, using the following line instead also known to works 
    #config.action_controller.relative_url_root = '/grader'

    #font path
    config.assets.paths << "#{Rails}/vendor/assets/fonts"
    config.assets.paths << Rails.root.join("app", "assets", "fonts")

    config.assets.precompile += ['announcement_refresh.js','effects.js','site_update.js']
    config.assets.precompile += ['local_jquery.js','tablesorter-theme.cafe.css']
    %w( announcements submissions configurations contests contest_management graders heartbeat 
        login main messages problems report site sites sources tasks 
        test user_admin users testcases).each do |controller|
      config.assets.precompile += ["#{controller}.js", "#{controller}.css"]
    end

    #load our application additional config
    config.worker = Rails.application.config_for(:worker)
  end
end
