# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )
Rails.application.config.assets.precompile += ['announcement_refresh.js','effects.js','site_update.js']
Rails.application.config.assets.precompile += ['local_jquery.js','tablesorter-theme.cafe.css']
%w( announcements submissions configurations contests contest_management graders heartbeat
    login main messages problems report site sites sources tasks groups
    test user_admin users tags testcases).each do |controller|
  Rails.application.config.assets.precompile += ["#{controller}.js", "#{controller}.css"]
end
