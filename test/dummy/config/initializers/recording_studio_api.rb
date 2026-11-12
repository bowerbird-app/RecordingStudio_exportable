# frozen_string_literal: true

return unless defined?(RecordingStudioApi)

RecordingStudioApi.configure do |config|
  config.rate_limit_oauth_enabled = false
  config.rate_limit_api_pre_auth_enabled = false
  config.rate_limit_api_enabled = false
  config.rate_limit_fail_closed = false
  config.api_management_authorization_required = false
  # No admin root in this dummy. Default ["AdminRoot"] would make AdminApi
  # declare an unregistered parent when CI eager-loads the model.
  config.admin_root_recordable_type_names = []
end

Rails.application.config.to_prepare do
  next if RecordingStudioApi.recordable_registration_for("Document")

  RecordingStudioApi.register_recordable_type_api(
    "Document",
    serializer: ->(document, **) { { title: document.title } },
    output_keys: %i[title],
    operations: %i[show],
    auto_capability_actions: false,
    capability_actions: %i[export export_keys]
  )
end
