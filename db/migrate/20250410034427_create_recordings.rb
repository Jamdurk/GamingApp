class CreateRecordings < ActiveRecord::Migration[7.2]
  def change
    create_table :recordings do |t|
      t.string :title
      t.string :game_name
      t.date :date_played
      t.text :players

      t.timestamps
    end
  end
end
