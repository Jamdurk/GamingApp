class CreateSegments < ActiveRecord::Migration[7.2]
  def change
    create_table :segments do |t|
      t.float :start_time
      t.float :end_time
      t.text :text
      t.references :transcript, null: false, foreign_key: true

      t.timestamps
    end
  end
end
