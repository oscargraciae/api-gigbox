FactoryGirl.define do
  factory :comment do
    body "MyString"
    active false
    service nil
    user nil
    parent 1
  end
end
