class CreateComments < ActiveRecord::Migration
  def change
    create_table :comments do |t|
      t.string :body
      t.boolean :active, default: true
      t.references :service, index: true, foreign_key: true
      t.references :user, index: true, foreign_key: true
      t.integer :parent

      t.timestamps null: false
    end
  end
end
