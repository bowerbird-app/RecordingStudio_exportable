# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_management_current_actor_resolver = ->(controller: nil) { controller&.send(:current_user) || Current.actor }

  config.access_management_authorizer = lambda do |recording:, actor: nil, controller: nil|
    actor ||= controller&.send(:current_user) || Current.actor
    actor.present? && recording.present?
  end

  config.mounted_page_authorizer = lambda do |controller:, actor: nil, recording: nil|
    actor ||= controller&.send(:current_user) || Current.actor
    actor.present? && recording.present?
  end
end

ActiveSupport.on_load(:active_record) do
  Rails.application.config.to_prepare do
    RecordingStudio.enable_capability(:accessible, on: "DemoDashboard") if defined?(DemoDashboard)
    RecordingStudio.enable_capability(:accessible, on: "Article") if defined?(Article)
    RecordingStudio.enable_capability(:accessible, on: "Author") if defined?(Author)
    RecordingStudio.enable_capability(:accessible, on: "Topic") if defined?(Topic)
    RecordingStudio.enable_capability(:accessible, on: "Document") if defined?(Document)
    RecordingStudio.enable_capability(:accessible, on: "Item") if defined?(Item)
  end
end
