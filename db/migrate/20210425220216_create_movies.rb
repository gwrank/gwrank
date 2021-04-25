class CreateMovies < ActiveRecord::Migration[6.1]
  def change
    create_table :movies do |t|
      t.references :player, null: false, foreign_key: true
      t.string :provider
      t.string :video_url
      t.integer :movieable_id
      t.string :movieable_type

      t.timestamps
    end
  end
end
