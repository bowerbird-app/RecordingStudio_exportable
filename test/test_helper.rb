# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "active_record"
require "action_controller"
require "recording_studio_exportable"

# Explicitly require engine models and controllers that aren't auto-loaded
# outside of a full Rails application boot. These must be loaded after the
# engine initializes but before tests run.
require_relative "../app/models/recording_studio_exportable/export_log"
require_relative "../app/controllers/recording_studio_exportable/application_controller"
require_relative "../app/controllers/recording_studio_exportable/exports_controller"

# Set up an in-memory SQLite database so ActiveRecord-dependent tests can run
# without a PostgreSQL server.
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# SQLite doesn't support UUID columns natively, but our ExportLog model uses UUIDs
# in PostgreSQL. For testing, we use integer IDs with string UUID columns.
# Also, ActiveRecord 8 prevents columns named 'attributes' by default; disable that
# check so the schema matches the actual migration.
ActiveRecord::Base.connection.create_table :recording_studio_exportable_export_logs, id: false do |t|
  t.string :id, primary_key: true, null: false
  t.string :context_recording_id
  t.string :context_recordable_type
  t.string :context_recordable_id
  t.string :export_key, null: false
  t.string :screen_key
  t.string :format, null: false, default: "csv"
  t.string :actor_type
  t.string :actor_id
  t.string :impersonator_type
  t.string :impersonator_id
  t.string :status, null: false, default: "pending"
  t.string :filename
  t.string :content_type, null: false
  t.integer :row_count, null: false, default: 0
  t.integer :byte_size, null: false, default: 0
  t.text :attributes, default: "[]"
  t.text :filters, default: "{}"
  t.text :metadata, default: "{}"
  t.datetime :started_at
  t.datetime :completed_at
  t.datetime :failed_at
  t.string :error_class
  t.text :error_message
  t.datetime :created_at, null: false
  t.datetime :updated_at, null: false
end

# Disable DangerousAttributeError — the 'attributes' column is intentional
# in this engine's schema.
ActiveRecord::Base.singleton_class.prepend(Module.new do
  def dangerous_attribute_method?(*)
    false
  end
end)

# ---------------------------------------------------------------------------
# Minitest 6 removed Object#stub — restore compatibility for tests that call
# stub on modules, classes, and other objects directly.
# This mimics Minitest 5 behavior: if the replacement value is callable (Proc,
# Method, etc.), it is called with the original method's arguments; otherwise
# the value is returned directly.
# ---------------------------------------------------------------------------
unless Object.new.respond_to?(:stub)
  class Object
    def stub(method, value)
      had_method = respond_to?(method)
      original = method(method) if had_method

      if value.respond_to?(:call)
        singleton_class.define_method(method) { |*args, **kwargs, &block| value.call(*args, **kwargs, &block) }
      else
        singleton_class.define_method(method) { |*| value }
      end

      yield
    ensure
      singleton_class.remove_method(method)
      original.owner.define_method(method, original) if had_method && original && original.owner == singleton_class
    end
  end
end

# Define a minimal RecordingStudio::Recording stub model so belongs_to
# associations in ExportLog resolve without loading the full gem's engine.
module RecordingStudio
  class Recording < ActiveRecord::Base
    self.table_name = "recording_studio_recordings"
  end
end

# Define RecordingStudio::Event stub
module RecordingStudio
  class Event < ActiveRecord::Base
    self.table_name = "recording_studio_events"
  end
end

# Create the recordings table needed by ExportLog's foreign key
ActiveRecord::Base.connection.create_table :recording_studio_recordings, id: :string, if_not_exists: true do |t|
  t.string :recordable_type
  t.string :recordable_id
end

# Create the events table
ActiveRecord::Base.connection.create_table :recording_studio_events, id: :string, if_not_exists: true do |t|
  t.string :action
  t.string :recording_id
  t.string :recordable_type
  t.string :recordable_id
  t.string :actor_type
  t.string :actor_id
  t.string :impersonator_type
  t.string :impersonator_id
  t.json :metadata
  t.datetime :created_at, null: false
  t.datetime :updated_at, null: false
end
