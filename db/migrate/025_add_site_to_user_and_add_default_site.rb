class AddSiteToUserAndAddDefaultSite < ActiveRecord::Migration[4.2]
  def self.up
    default_site = Site.new({:name => 'default',
                              :started => false})
    default_site.save!

    add_column :users, :site_id, :integer
    User.reset_column_information

    User.all.each do |user|

      class << user
        def valid?
          true
        end
      end

      user.site_id = default_site.id
      user.save
    end
  end

  def self.down
    remove_column :users, :site_id

    default_site = Site.find_by_name('default')
    default_site.destroy if default_site
  end
end
