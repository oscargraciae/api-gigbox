class CreateLogApis < ActiveRecord::Migration
  def change
    create_table :log_apis do |t|
      t.string :name
      t.timestamps null: false
    end
  end
end
