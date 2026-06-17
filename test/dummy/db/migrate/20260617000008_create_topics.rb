class CreateTopics < ActiveRecord::Migration[8.1]
  def change
    create_table :topics, id: :uuid do |t|
      t.references :article, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end
  end
end