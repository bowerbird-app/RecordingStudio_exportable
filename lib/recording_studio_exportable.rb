# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
require "flat_pack"
require "active_support/core_ext/string/inflections"
require "recording_studio_exportable/version"
require "recording_studio_exportable/errors"
require "recording_studio_exportable/export_definition"
require "recording_studio_exportable/configuration"
require "recording_studio_exportable/exporter"
require "recording_studio_exportable/capabilities/exportable"
require "recording_studio_exportable/services/base_service"
require "recording_studio_exportable/services/example_service"
require "recording_studio_exportable/engine"

module RecordingStudioExportable
  EXPORTS_GLOBS = [
    "app/services/exports/**/*_export.rb",
    "services/exports/**/*_export.rb"
  ].freeze

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def auto_register_exports!(config = configuration)
      export_file_paths.each do |file_path|
        load_export_file(file_path)

        export_class_for(file_path)&.then do |export_class|
          export_class.register(config) if export_class.respond_to?(:register)
        end
      end
    end

    def export(context_recording:, actor:, export_key: nil, attributes: nil, filters: {}, format: :csv,
               filename: nil, controller: nil)
      Exporter.call(
        context_recording: context_recording,
        actor: actor,
        export_key: export_key,
        attributes: attributes,
        filters: filters,
        format: format,
        filename: filename,
        controller: controller
      )
    end

    private

    def export_file_paths
      roots = [Rails.root, *engine_roots].compact.uniq
      roots.flat_map do |root|
        EXPORTS_GLOBS.flat_map { |glob| Dir[root.join(glob)] }
      end.uniq.sort
    end

    def engine_roots
      return [] unless defined?(Rails::Engine)

      Rails::Engine.subclasses.filter_map do |engine_class|
        engine_class.respond_to?(:root) ? engine_class.root : nil
      end
    end

    def load_export_file(file_path)
      if defined?(require_dependency)
        require_dependency(file_path)
      else
        require file_path
      end
    end

    def export_class_for(file_path)
      relative_path = file_path.to_s.split("/services/exports/").last
      return if relative_path.blank?

      class_name = relative_path.delete_suffix(".rb").split("/").map(&:camelize).join("::")
      class_name.safe_constantize
    end
  end
end
