# == Schema Information
#
# Table name: order_statuses
#
#  id          :integer          not null, primary key
#  name        :string
#  description :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

FactoryGirl.define do
  factory :order_status do
    name 'MyString'
    description 'MyString'
  end
end
