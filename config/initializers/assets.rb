# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
# Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )
Rails.application.config.assets.precompile += %w(jquery.js bootstrap.min.js popper.js)

Rails.application.config.assets.precompile += ['announcement_refresh.js','effects.js','site_update.js']
Rails.application.config.assets.precompile += ['local_jquery.js','tablesorter-theme.cafe.css']
%w( announcements submissions configurations contests contest_management graders heartbeat
    login main messages problems report site sites sources tasks groups
    test user_admin users tags testcases).each do |controller|
  Rails.application.config.assets.precompile += ["#{controller}.js", "#{controller}.css"]
end

