class CreateAuthors < ActiveRecord::Migration[8.1]
  def change
    create_table :authors, id: :uuid do |t|
      t.string :name, null: false
      t.text :bio, null: false, default: ""

      t.timestamps
    end
  end
end