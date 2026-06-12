# frozen_string_literal: true

require "monitor"
require "active_support/core_ext/object/blank"
require_relative "hooks"

module RecordingStudioExportable
  class Configuration
    DEFAULT_ROW_LIMIT = 10_000

    attr_accessor :default_row_limit, :default_required_role
    attr_reader :export_definitions, :hooks

    def initialize
      @default_row_limit = DEFAULT_ROW_LIMIT
      @default_required_role = :view
      @export_definitions = {}
      @hooks = Hooks.new
      @mutex = Monitor.new
    end

    def register_export(key, replace: false, **options, &block)
      definition = ExportDefinition.new(
        key: normalize_key(key),
        row_limit: default_row_limit,
        required_role: default_required_role,
        **options,
        &block
      )

      @mutex.synchronize do
        if @export_definitions.key?(definition.key) && !replace
          existing = @export_definitions.fetch(definition.key)
          return existing if existing.equivalent_to?(definition)

          raise DuplicateExportDefinition, "export definition #{definition.key.inspect} is already registered"
        end

        @export_definitions[definition.key] = definition
      end

      definition
    end
    alias export register_export

    def replace_export(key, **options, &block)
      register_export(key, replace: true, **options, &block)
    end

    def export_definition(key)
      @mutex.synchronize { @export_definitions[normalize_key(key)] }
    end

    def fetch_export_definition!(key)
      export_definition(key) || raise(UnknownExportDefinition, "unknown export definition #{normalize_key(key).inspect}")
    end

    def export_enabled_for_recording?(key, recording)
      keys = enabled_export_keys_for(recording)
      keys.nil? || keys.include?(normalize_key(key))
    end

    def export_keys_for(recording:, actor:, context: nil)
      keys = enabled_export_keys_for(recording)
      @mutex.synchronize do
        @export_definitions.values.select do |definition|
          next false if keys && !keys.include?(definition.key)

          definition.available_for?(recording: recording, actor: actor, context: context)
        end.map(&:key).sort
      end
    end

    def normalize_key(key)
      normalized = key.to_s.strip.downcase.tr("-", "_").gsub(%r{[^a-z0-9_.:/]+}, "_")
      normalized = normalized.tr(":/", ".").gsub(/\.+/, ".").gsub(/\A\.|\.\z/, "")
      raise InvalidExportDefinition, "export key is required" if normalized.empty?

      normalized
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end

    def to_h
      {
        default_row_limit: default_row_limit,
        default_required_role: default_required_role,
        export_definitions: @export_definitions.keys.sort,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    private

    def enabled_export_keys_for(recording)
      return unless recording

      type_name = recording.respond_to?(:recordable_type) ? recording.recordable_type : nil
      return if type_name.blank?

      options = RecordingStudio.capability_options(:exportable, for: type_name)
      return [] unless options

      Array(options.fetch(:export_keys, nil)).map { |key| normalize_key(key) }
    rescue StandardError
      []
    end
  end
end
