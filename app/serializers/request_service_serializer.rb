# == Schema Information
#
# Table name: request_services
#
#  id                 :integer          not null, primary key
#  message            :text
#  request_date       :date
#  request_time       :time
#  request_status_id  :integer          default(1)
#  service_id         :integer
#  user_id            :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  price              :decimal(, )
#  fee                :decimal(, )
#  supplier_id        :integer
#  is_finish_supplier :boolean          default(FALSE)
#  is_finish_customer :boolean          default(FALSE)
#  is_evaluated       :boolean          default(FALSE)
#  total              :decimal(, )
#  token_card         :string
#  subtotal           :decimal(8, 2)
#  quantity           :integer          default(1)
#  package_id         :integer
#

class RequestServiceSerializer < ActiveModel::Serializer
  attributes :id, :message, :request_date, :request_time, :price, :subtotal, :fee, :total, :quantity, :created_at, :is_finish_supplier, :is_finish_customer, :is_evaluated, :updated_at, :is_declined_card

  has_one :request_status
  has_one :user, serializer: UserPrivateInfoSerializer
  has_one :supplier, serializer: UserPrivateInfoSerializer
  has_one :service, serializer: ServicePrivateSummarySerializer
  has_one :package

  def request_message
    object.request_message.order(created_at: :desc)
  end
end
