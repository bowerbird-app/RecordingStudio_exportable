# frozen_string_literal: true

class CreateRecordingStudioExportableExportLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_studio_exportable_export_logs, id: :uuid do |t|
      t.references :context_recording,
                   null: false,
                   type: :uuid,
                   foreign_key: { to_table: :recording_studio_recordings },
                   index: { name: "idx_rs_exportable_logs_on_context_recording_id" }
      t.string :export_key, null: false
      t.string :actor_type
      t.uuid :actor_id
      t.string :impersonator_type
      t.uuid :impersonator_id
      t.string :status, null: false, default: "pending"
      t.string :filename
      t.string :content_type, null: false
      t.integer :row_count, null: false, default: 0
      t.json :filters, null: false, default: {}
      t.string :error_class
      t.string :error_message
      t.timestamps

      t.index :export_key, name: "idx_rs_exportable_logs_on_export_key"
      t.index [:actor_type, :actor_id], name: "idx_rs_exportable_logs_on_actor"
      t.index [:impersonator_type, :impersonator_id], name: "idx_rs_exportable_logs_on_impersonator"
      t.index :created_at, name: "idx_rs_exportable_logs_on_created_at"
      t.index :status, name: "idx_rs_exportable_logs_on_status"
    end
  end
end
