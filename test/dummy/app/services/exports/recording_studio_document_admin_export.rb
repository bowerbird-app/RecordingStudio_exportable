class RecordingStudioDocumentAdminExport
  KEY = "recording_studio_document_admin_export".freeze

  def self.register(config)
    config.register_export(
      KEY,
      label: "Document admin export",
      description: "Exports document items for an admin grant.",
      required_role: :admin,
      context_types: [ "Document" ],
      columns: [
        { key: :item_name, label: "Item", value: :name }
      ],
      filename: "document-admin.csv"
    ) do |context_recording:, **|
      context_recording.recordable.items.order(:name)
    end
  end
end
