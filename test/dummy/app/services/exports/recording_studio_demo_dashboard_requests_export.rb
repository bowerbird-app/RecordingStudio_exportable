class RecordingStudioDemoDashboardRequestsExport
  KEY = "recording_studio_demo_dashboard_requests_export".freeze

  def self.register(config)
    config.register_export(
      KEY,
      label: "Demo API requests",
      description: "Exports the API request rows shown on the demo dashboard.",
      required_role: :view,
      context_types: [ "DemoDashboard" ],
      columns: [
        { key: :path, label: "Path", value: :path },
        { key: :method, label: "Method", value: :http_method },
        { key: :status, label: "Status", value: :status },
        { key: :duration_ms, label: "Duration (ms)", value: :duration_ms }
      ],
      allowed_attributes: {
        demo_api_requests: [
          { key: :path, label: "Path", value: :path },
          { key: :http_method, label: "Method", value: :http_method },
          { key: :status, label: "Status", value: :status },
          { key: :duration_ms, label: "Duration (ms)", value: :duration_ms }
        ]
      },
      filename: method(:filename)
    ) do |context_recording:, filters:, **|
      resolve_rows(context_recording: context_recording, filters: filters)
    end
  end

  def self.filename(context_recording:, **)
    "#{context_recording.recordable.name}-api-requests.csv"
  end

  def self.resolve_rows(context_recording:, filters:)
    scope = context_recording.recordable.demo_api_requests.order(:created_at)
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    scope
  end
end
