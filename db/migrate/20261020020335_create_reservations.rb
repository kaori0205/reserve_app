class CreateReservations < ActiveRecord::Migration[8.1]
  def change
    create_table :reservations do |t|
      t.references :room, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :people, null: false
      t.datetime :start_at
      t.datetime :end_at
      t.integer :status, null: false, default: 0
      t.timestamps
    end
  end
end
