class CreateDemoDashboards < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_dashboards, id: :uuid do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end
