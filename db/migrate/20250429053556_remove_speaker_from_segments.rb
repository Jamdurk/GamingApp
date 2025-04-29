class RemoveSpeakerFromSegments < ActiveRecord::Migration[7.2]
  def change
    remove_column :segments, :speaker, :string
  end
end
