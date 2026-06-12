# frozen_string_literal: true

RecordingStudioExportable.configure do |config|
  config.export(
    "demo.dashboard_requests",
    label: "Demo API requests",
    description: "Exports the API request rows shown on the demo dashboard.",
    headers: [ "Path", "Method", "Status", "Duration (ms)" ],
    filename: ->(recording:, **) { "#{recording.recordable.name}-api-requests.csv" }
  ) do |recording:, **|
    recording.recordable.demo_api_requests.order(:created_at).map do |request|
      {
        "Path" => request.path,
        "Method" => request.http_method,
        "Status" => request.status,
        "Duration (ms)" => request.duration_ms
      }
    end
  end
end

ActiveSupport.on_load(:active_record) do
  Rails.application.config.to_prepare do
    next unless defined?(DemoDashboard)

    RecordingStudio::Exportable::Capabilities::Exportable.enabled(
      on: "DemoDashboard",
      exports: [ "demo.dashboard_requests" ]
    )
  end
end
