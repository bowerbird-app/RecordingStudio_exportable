class Document < ApplicationRecord
  EXPORT_KEYS = ["recording_studio_document_items_export"].freeze

  recording_studio_recordable label: "Document", root: true

  has_many :items, dependent: :destroy

  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: EXPORT_KEYS
  )
end
