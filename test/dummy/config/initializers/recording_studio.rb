# frozen_string_literal: true

RecordingStudio.configure do |config|
  # Registered delegated_type recordables (strings or classes)
  config.recordable_types = [ "Workspace", "Folder", "Page", "DemoDashboard", "DemoApiRequest", "Article", "Author", "Topic", "Document", "Item" ]
  # API 1.16 declares AdminApi only when an admin root type is loaded.
  # This dummy has none, so listing AdminApi here fails boot.
  config.recordable_types += ["RecordingStudio::Access", "RecordingStudioApi::ApiClient", "RecordingStudioApi::ApiCredential", "RecordingStudioApi::ApiAccessToken"] if defined?(RecordingStudioApi)

  # Require each configured ActiveRecord type to call recording_studio_recordable.
  config.require_recordable_declarations = true

  # Actor resolver for events when no actor is explicitly supplied
  config.actor = -> { Current.actor }

  # Recording Studio 7 denies record! and create_root_recording! unless an
  # authorizer is set. This dummy grants a write when an actor is present,
  # including a new root where root_recording is nil. Seeds and tests record
  # before access exists. Do not set allow_unauthorized_writes.
  config.authorize_write = ->(actor:, **) { actor.present? }

  # Emit ActiveSupport::Notifications events
  config.event_notifications_enabled = true

  # Idempotency behavior for log_event!
  config.idempotency_mode = :return_existing # or :raise

  # Recordable duplication strategy for revisions
  config.recordable_dup_strategy = :dup
end
