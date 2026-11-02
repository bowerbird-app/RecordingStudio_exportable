# frozen_string_literal: true

class RenameExportLogAttributesToSelectedColumns < ActiveRecord::Migration[8.1]
  def change
    rename_column :recording_studio_exportable_export_logs, :attributes, :selected_columns
  end
end
