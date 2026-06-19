class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items, id: :uuid do |t|
      t.references :document, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false, default: ""

      t.timestamps
    end
  end
end
