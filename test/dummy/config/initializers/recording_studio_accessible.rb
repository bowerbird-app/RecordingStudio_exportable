# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User", "RecordingStudioApi::ApiClient" ].uniq
  config.access_management_current_actor_resolver = lambda do |controller: nil|
    Current.actor || (controller.current_user if controller.respond_to?(:current_user))
  end

  config.access_management_authorizer = lambda do |recording:, actor: nil, controller: nil|
    actor ||= Current.actor || (controller.current_user if controller.respond_to?(:current_user))
    actor.present? && recording.present?
  end

  config.mounted_page_authorizer = lambda do |controller:, actor: nil, recording: nil|
    actor ||= Current.actor || (controller.current_user if controller.respond_to?(:current_user))
    actor.present? && recording.present?
  end
end

ActiveSupport.on_load(:active_record) do
  Rails.application.config.to_prepare do
    RecordingStudio.enable_capability(:accessible, on: "Workspace") if defined?(Workspace)
    RecordingStudio.enable_capability(:accessible, on: "DemoDashboard") if defined?(DemoDashboard)
    RecordingStudio.enable_capability(:accessible, on: "Article") if defined?(Article)
    RecordingStudio.enable_capability(:accessible, on: "Author") if defined?(Author)
    RecordingStudio.enable_capability(:accessible, on: "Topic") if defined?(Topic)
    RecordingStudio.enable_capability(:accessible, on: "Document") if defined?(Document)
    RecordingStudio.enable_capability(:accessible, on: "Item") if defined?(Item)
  end
end
