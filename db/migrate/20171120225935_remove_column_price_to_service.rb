class RemoveColumnPriceToService < ActiveRecord::Migration
  def change
    remove_column :services, :price
    remove_column :services, :is_fixed_price
    remove_column :services, :unit_type_id
    remove_column :services, :unit_max
  end
end
