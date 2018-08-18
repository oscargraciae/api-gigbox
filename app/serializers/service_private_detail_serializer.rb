class ServicePrivateDetailSerializer < ActiveModel::Serializer
  attributes :id, :name, :description, :cover, :rating_general, :service_ratings, :published, :created_at, :updated_at, :visits, :total_jobs

  has_one :category
  has_one :sub_category

end
