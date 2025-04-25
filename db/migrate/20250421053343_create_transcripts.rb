class CreateTranscripts < ActiveRecord::Migration[7.2]
  def change
    create_table :transcripts do |t|
      t.references :recording, null: false, foreign_key: true
      t.json :data # Manually added
      t.timestamps
    end
  end
end
