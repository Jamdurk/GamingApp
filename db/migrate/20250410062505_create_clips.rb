class CreateClips < ActiveRecord::Migration[7.2]
  def change
    create_table :clips do |t|
      t.string :title
      t.integer :start_time
      t.integer :end_time
      t.references :recording, null: false, foreign_key: true

      t.timestamps
    end
  end
end
