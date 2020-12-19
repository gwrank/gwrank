class CreateRegistrations < ActiveRecord::Migration[6.1]
  def change
    create_table :registrations do |t|
      t.references :player, null: false, foreign_key: true
      t.datetime :registered_at
      t.datetime :unregistered_at

      t.timestamps
    end
  end
end
