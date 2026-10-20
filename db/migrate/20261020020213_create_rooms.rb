class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.string :name, null: false
      t.integer :capacity, null: false
      t.integer :price_per_30min, null: false
      t.timestamps
    end

    add_index :rooms, :name, unique: true
  end
end
