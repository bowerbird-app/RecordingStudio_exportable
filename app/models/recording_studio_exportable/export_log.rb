# frozen_string_literal: true

module RecordingStudioExportable
  class ExportLog < ActiveRecord::Base
    self.table_name = "recording_studio_exportable_export_logs"

    belongs_to :recording, class_name: "RecordingStudio::Recording"
    belongs_to :actor, polymorphic: true, optional: true

    validates :export_key, :filename, :content_type, presence: true
    validates :row_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
