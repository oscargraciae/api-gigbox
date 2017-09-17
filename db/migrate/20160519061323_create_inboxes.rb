class CreateInboxes < ActiveRecord::Migration
  def change
    create_table :inboxes do |t|
      t.integer :sender_id
      t.integer :recipient_id

      t.timestamps null: false
    end
  end
end
