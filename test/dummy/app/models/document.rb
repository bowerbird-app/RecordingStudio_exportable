class Document < ApplicationRecord
  recording_studio_recordable label: "Document", root: true

  has_many :items, dependent: :destroy

  RecordingStudio::Exportable::Capabilities::Exportable.enabled(
    export_keys: ["recording_studio_document_items_export"]
  )
end
