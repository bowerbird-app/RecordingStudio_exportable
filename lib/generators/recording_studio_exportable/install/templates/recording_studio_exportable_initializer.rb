# frozen_string_literal: true

RecordingStudioExportable.configure do |config|
  # Fail closed if an export returns more rows than expected.
  # config.max_rows = 10_000

  # Default role checked through RecordingStudioAccessible.authorized?.
  # config.default_required_role = :view

  # Register exports with stable namespaced keys.
  # config.register_export "reports.example", columns: [{ key: :name, label: "Name", value: :name }], filename: "example.csv" do |context_recording:, **|
  #   [{ name: RecordingStudio.recordable_name(context_recording.recordable) }]
  # end
end
