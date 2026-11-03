# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "securerandom"
require "minitest/mock"
require "rails"
require "active_record"
require "action_controller"
require "recording_studio_exportable"

layout_helper = RecordingStudio::Engine.root.join("app/helpers/recording_studio/layout_helper.rb")
require layout_helper if layout_helper.file?

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
ActiveRecord::Base.connection.create_table :recording_studio_exportable_export_logs, id: false do |t|
  t.string :id, primary_key: true, null: false, default: lambda {
    "lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || substr(hex(randomblob(2)), 2) || '-' || substr('89ab', 1 + abs(random()) % 4, 1) || substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6)))"
  }
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
  t.text :selected_columns, default: "[]"
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

module ExportableConfigurationIsolation
  CONFIGURATION_ACCESSORS = RecordingStudioExportable::Configuration
                            .instance_methods(false)
                            .select { |name| name.end_with?("=") }
                            .map { |name| name.to_s.delete_suffix("=").to_sym }
                            .select { |name| RecordingStudioExportable::Configuration.method_defined?(name) }
                            .freeze

  def save_exportable_configuration!
    configuration = RecordingStudioExportable.configuration
    @saved_exportable_accessors = CONFIGURATION_ACCESSORS.to_h { |name| [name, configuration.public_send(name)] }
    @saved_exportable_definitions = configuration.export_definitions.dup

    defaults = RecordingStudioExportable::Configuration.new
    RecordingStudioExportable.configure do |config|
      CONFIGURATION_ACCESSORS.each do |name|
        config.public_send("#{name}=", defaults.public_send(name))
      end
      config.export_definitions.clear
    end
  end

  def restore_exportable_configuration!
    return unless defined?(@saved_exportable_accessors) && @saved_exportable_accessors

    RecordingStudioExportable.configure do |config|
      CONFIGURATION_ACCESSORS.each do |name|
        config.public_send("#{name}=", @saved_exportable_accessors[name])
      end
      config.export_definitions.clear
      @saved_exportable_definitions.each do |key, definition|
        config.export_definitions[key] = definition
      end
    end
  end
end

Minitest::Test.include(ExportableConfigurationIsolation)

# Create the recordings table needed by ExportLog's foreign key
ActiveRecord::Base.connection.create_table :recording_studio_recordings, id: :string, if_not_exists: true do |t|
  t.string :recordable_type
  t.string :recordable_id
end
