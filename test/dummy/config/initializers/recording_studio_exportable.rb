# frozen_string_literal: true

RecordingStudioExportable.configure do |config|
  config.current_actor = ->(controller: nil) { controller&.send(:current_user) || Current.actor }

  config.register_export(
    "demo.dashboard_requests",
    label: "Demo API requests",
    description: "Exports the API request rows shown on the demo dashboard.",
    context_types: [ "DemoDashboard" ],
    columns: [
      { key: :path, label: "Path", value: :path },
      { key: :method, label: "Method", value: :http_method },
      { key: :status, label: "Status", value: :status },
      { key: :duration_ms, label: "Duration (ms)", value: :duration_ms }
    ],
    filename: ->(context_recording:, **) { "#{context_recording.recordable.name}-api-requests.csv" }
  ) do |context_recording:, filters:, **|
    scope = context_recording.recordable.demo_api_requests.order(:created_at)
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope
  end
end

ActiveSupport.on_load(:active_record) do
  Rails.application.config.to_prepare do
    next unless defined?(DemoDashboard)

    RecordingStudio::Exportable::Capabilities::Exportable.enabled(
      on: "DemoDashboard",
      export_keys: [ "demo.dashboard_requests" ]
    )
  end
end
