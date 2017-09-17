# == Schema Information
#
# Table name: inbox_messages
#
#  id          :integer          not null, primary key
#  message     :string
#  sender_user :integer
#  inbox_id    :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  readit      :boolean          default(FALSE)
#

class InboxMessage < ActiveRecord::Base
  belongs_to :sender, class_name: 'User', foreign_key: 'sender_user'
  belongs_to :inbox

  validates_presence_of :message, :inbox_id, :sender_user

end
