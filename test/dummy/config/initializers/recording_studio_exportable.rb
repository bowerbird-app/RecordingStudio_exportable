# frozen_string_literal: true

RecordingStudioExportable.configure do |config|
  config.current_actor = ->(controller: nil) { controller&.send(:current_user) || Current.actor }

  RecordingStudioExportable.auto_register_exports!(config)

  Rails.application.config.to_prepare do
    RecordingStudioExportable.auto_register_exports!(config)
  end
end
