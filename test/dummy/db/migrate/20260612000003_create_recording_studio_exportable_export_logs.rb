class CreateRecordingStudioExportableExportLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_exportable_export_logs, id: :uuid do |t|
      t.string :export_key, null: false
      t.references :recording,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :recording_studio_recordings },
                   index: { name: "idx_rs_exportable_logs_on_recording_id" }
      t.string :actor_type
      t.uuid :actor_id
      t.string :filename, null: false
      t.string :content_type, null: false
      t.integer :row_count, null: false, default: 0
      t.timestamps

      t.index :export_key, name: "idx_rs_exportable_logs_on_export_key"
      t.index [:actor_type, :actor_id], name: "idx_rs_exportable_logs_on_actor"
      t.index :created_at, name: "idx_rs_exportable_logs_on_created_at"
    end
  end
end
