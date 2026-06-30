# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
require "flat_pack"
require "active_support/core_ext/string/inflections"
require "recording_studio_exportable/version"
require "recording_studio_exportable/errors"
require "recording_studio_exportable/export_definition"
require "recording_studio_exportable/trusted_export_token_store"
require "recording_studio_exportable/configuration"
require "recording_studio_exportable/exporter"
require "recording_studio_exportable/trusted_export_token"
require "recording_studio_exportable/capabilities/exportable"
require "recording_studio_exportable/services/base_service"
require "recording_studio_exportable/services/example_service"
require "recording_studio_exportable/engine"
require "pathname"

module RecordingStudioExportable
  EXPORTS_GLOBS = [
    "app/services/exports/**/*_export.rb",
    "services/exports/**/*_export.rb"
  ].freeze
  EXPORTS_LOAD_PATHS = [
    Pathname.new("app/services/exports"),
    Pathname.new("services/exports")
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

    def issue_trusted_token(context_recording:, actor:, source:, screen_identifier:,
                            columns:, row_resolver:, ttl: TrustedExportToken::DEFAULT_TTL)
      TrustedExportToken.issue(
        context_recording: context_recording,
        actor: actor,
        source: source,
        screen_identifier: screen_identifier,
        columns: columns,
        row_resolver: row_resolver,
        ttl: ttl
      )
    end

    def export_from_token(token_id:, format: :csv, filename: nil, filters: {}, controller: nil)
      token = TrustedExportToken.find_and_consume!(token_id)
      Exporter.call(
        context_recording: token.context_recording,
        actor: token.actor,
        export_key: token.effective_export_key,
        trusted_export: true,
        rows: token.row_resolver,
        columns: token.columns,
        trusted_source: token.source,
        screen_identifier: token.screen_identifier,
        format: format,
        filename: filename,
        filters: filters,
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
      relative_path = export_relative_path_for(file_path)
      return if relative_path.blank?

      class_name = relative_path.delete_suffix(".rb").split("/").map(&:camelize).join("::")
      class_name.safe_constantize
    end

    def export_relative_path_for(file_path)
      path = Pathname.new(file_path).expand_path

      export_roots.each do |root|
        relative_path = path.relative_path_from(root)
        next unless relative_export_path?(relative_path)

        return relative_path.to_s
      rescue ArgumentError
        next
      end

      nil
    end

    def export_roots
      [Rails.root, *engine_roots].compact.uniq.flat_map do |root|
        root_path = Pathname.new(root).expand_path
        EXPORTS_LOAD_PATHS.map { |load_path| root_path.join(load_path) }
      end
    end

    def relative_export_path?(relative_path)
      parts = relative_path.each_filename.to_a
      parts.any? && parts.exclude?("..")
    end
  end
end
