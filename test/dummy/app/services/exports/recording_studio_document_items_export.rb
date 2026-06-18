class RecordingStudioDocumentItemsExport
  KEY = "recording_studio_document_items_export".freeze

  def self.register(config)
    config.register_export(
      KEY,
      label: "Document items",
      description: "Exports items for the current document.",
      required_role: :view,
      context_types: ["Document"],
      columns: [
        { key: :item_name, label: "Item", value: :name },
        { key: :item_description, label: "Description", value: :description }
      ],
      allowed_attributes: {
        items: [
          { key: :name, label: "Item", value: :name },
          { key: :description, label: "Description", value: :description }
        ]
      },
      filename: method(:filename)
    ) do |context_recording:, **|
      context_recording.recordable.items.order(:name)
    end
  end

  def self.filename(context_recording:, **)
    title = context_recording.recordable.title.to_s.parameterize.presence || "document"
    "#{title}-items.csv"
  end
end
