# frozen_string_literal: true

RecordingStudioExportable.configure do |config|
  # Fail closed if an export returns more rows than expected.
  # config.default_row_limit = 10_000

  # Default role checked through RecordingStudioAccessible.authorized?.
  # config.default_required_role = :view

  # Register exports with stable namespaced keys.
  # config.export "reports.example", headers: ["Name"], filename: "example.csv" do |recording:, actor:, params:, context:|
  #   [{ "Name" => RecordingStudio.recordable_name(recording.recordable) }]
  # end
end
