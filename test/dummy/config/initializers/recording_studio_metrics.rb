# frozen_string_literal: true

# Dummy-only proof of the Metrics query DSL. The gem does not register metrics.
return unless defined?(RecordingStudioMetrics)

Rails.application.config.to_prepare do
  next if RecordingStudioMetrics.registry.find("exports.total")

  RecordingStudioMetrics.register(
    :exports,
    model: RecordingStudioExportable::ExportLog,
    api_authorize: ->(_context) { true }
  ) do
    count :total, title: "Exports"
  end
end
