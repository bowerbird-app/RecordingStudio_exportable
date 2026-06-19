class CreateDemoApiRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_api_requests, id: :uuid do |t|
      t.references :demo_dashboard, null: false, type: :uuid, foreign_key: true
      t.string :path, null: false
      t.string :http_method, null: false, default: "GET"
      t.integer :status, null: false
      t.integer :duration_ms, null: false
      t.timestamps
    end
  end
end
