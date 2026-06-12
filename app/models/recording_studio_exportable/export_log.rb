# frozen_string_literal: true

module RecordingStudioExportable
  class ExportLog < ActiveRecord::Base
    # Audit-only model. This engine intentionally ships no admin UI or policy layer;
    # host apps decide how export logs are exposed to operators.
    self.table_name = "recording_studio_exportable_export_logs"

    belongs_to :context_recording, class_name: "RecordingStudio::Recording"
    belongs_to :actor, polymorphic: true, optional: true
    belongs_to :impersonator, polymorphic: true, optional: true

    enum :status, { pending: "pending", running: "running", completed: "completed", failed: "failed" }, default: :pending

    scope :recent, -> { order(created_at: :desc) }
    scope :successful, -> { completed }
    scope :failed_attempts, -> { failed }

    validates :export_key, :content_type, :status, presence: true
    validates :row_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
