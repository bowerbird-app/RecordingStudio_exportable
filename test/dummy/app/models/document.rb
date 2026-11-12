class Document < ApplicationRecord
  recording_studio_recordable label: "Document", root: true

  has_many :items, dependent: :destroy

  include RecordingStudio::Capabilities::Exportable.to(
    export_keys: [
      "recording_studio_document_items_export",
      "recording_studio_document_admin_export"
    ]
  )

  RecordingStudio.enable_capability(:api_access_point, on: self) if defined?(RecordingStudioApi)
end
