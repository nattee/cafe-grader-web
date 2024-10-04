class AddMoreToContest < ActiveRecord::Migration[7.0]
  def change
    rename_column :contests, :name, :description
    rename_column :contests, :title, :name
    add_column :contests, :freeze, :bool, default: false
    add_column :contests, :remark, :text
  end
end
