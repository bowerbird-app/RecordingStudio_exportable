# frozen_string_literal: true

RecordingStudioExportable.configure do |config|
  config.current_actor = lambda do |controller: nil|
    Current.actor || (controller.current_user if controller.respond_to?(:current_user))
  end
  config.trusted_export_sources = %w[RecordingStudioExportable]

  RecordingStudioExportable.auto_register_exports!(config)

  Rails.application.config.to_prepare do
    RecordingStudioExportable.auto_register_exports!(config)
  end
end
