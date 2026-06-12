# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/string/inflections"

module RecordingStudioExportable
  class ExportDefinition
    Column = Struct.new(:key, :label, :value, keyword_init: true)

    CONTENT_TYPE = "text/csv; charset=utf-8"
    DEFAULT_FILENAME = "recording-export.csv"

    attr_reader :key, :label, :description, :context_types, :screen_keys, :columns,
                :default_columns, :filename, :required_role, :max_rows, :formats,
                :resolver, :context_predicate

    def initialize(key:, label: nil, description: nil, context_types: nil, screen_keys: nil,
                   columns: nil, default_columns: nil, headers: nil, filename: nil,
                   required_role: :view, max_rows: nil, row_limit: nil, formats: [:csv],
                   resolver: nil, context_predicate: nil, context_key: nil, exporter: nil, &block)
      @key = normalize_key!(key)
      @label = label.presence || @key.titleize
      @description = description.to_s
      @context_types = normalize_strings(context_types)
      @screen_keys = normalize_strings(screen_keys || context_key).map(&:underscore)
      @columns = normalize_columns!(columns || headers)
      @default_columns = normalize_default_columns(default_columns)
      @filename = filename
      @required_role = normalize_required_role!(required_role)
      @max_rows = normalize_max_rows!(max_rows || row_limit || Configuration::DEFAULT_MAX_ROWS)
      @formats = Array(formats.presence || :csv).map { |format| normalize_format(format) }.uniq
      @resolver = resolver || exporter || block
      @context_predicate = context_predicate

      validate!
    end

    def headers
      columns.map(&:label)
    end

    def row_limit
      max_rows
    end

    def equivalent_to?(other)
      other.is_a?(self.class) &&
        key == other.key &&
        context_types == other.context_types &&
        screen_keys == other.screen_keys &&
        columns.map(&:to_h) == other.columns.map(&:to_h) &&
        default_columns == other.default_columns &&
        filename == other.filename &&
        required_role == other.required_role &&
        max_rows == other.max_rows &&
        formats == other.formats &&
        resolver == other.resolver &&
        context_predicate == other.context_predicate
    end

    def available_for?(context_recording:, actor:, screen_key: nil)
      valid_for_context?(context_recording, screen_key: screen_key) &&
        actor.present? &&
        RecordingStudioAccessible.authorized?(actor: actor, recording: context_recording, role: required_role)
    end

    def validate_context!(context_recording, screen_key: nil)
      return true if valid_for_context?(context_recording, screen_key: screen_key)

      raise ExportNotAllowedForContext, "export #{key} is not allowed for this context"
    end

    def columns_for(attributes)
      keys = requested_column_keys(attributes)
      keys = default_columns if keys.empty?

      by_key = columns.index_by(&:key)
      unknown = keys - by_key.keys
      raise InvalidExportColumns, "unknown export columns: #{unknown.join(', ')}" if unknown.any?

      keys.map { |column_key| by_key.fetch(column_key) }
    end

    def resolve_rows(context_recording:, actor:, attributes:, filters:, format:, controller: nil)
      resolver.call(
        context_recording: context_recording,
        recording: context_recording,
        actor: actor,
        attributes: attributes,
        filters: filters,
        params: { attributes: attributes, filters: filters },
        format: format,
        context: nil,
        controller: controller
      )
    end

    def filename_for(context_recording:, actor:, attributes:, filters:, format:)
      value = if filename.respond_to?(:call)
                filename.call(
                  context_recording: context_recording,
                  recording: context_recording,
                  actor: actor,
                  attributes: attributes,
                  filters: filters,
                  format: format
                )
              else
                filename
              end

      value.presence || DEFAULT_FILENAME
    end

    private

    def validate!
      raise InvalidExportDefinition, "resolver must respond to call" unless resolver.respond_to?(:call)
      raise InvalidExportDefinition, "columns are required" if columns.empty?
      raise InvalidExportDefinition, "formats are required" if formats.empty?
      raise InvalidExportDefinition, "context_predicate must respond to call" if context_predicate && !context_predicate.respond_to?(:call)
    end

    def valid_for_context?(context_recording, screen_key:)
      return false unless context_recording

      context_type = context_recording.respond_to?(:recordable_type) ? context_recording.recordable_type : context_recording.class.name
      return false if context_types.any? && !context_types.include?(context_type)

      normalized_screen_key = screen_key.to_s.strip.underscore
      return false if screen_keys.any? && !screen_keys.include?(normalized_screen_key)

      return true unless context_predicate

      context_predicate.call(context_recording)
    end

    def requested_column_keys(attributes)
      case attributes
      when nil
        []
      when Hash
        values = attributes[:columns] || attributes["columns"]
        values.is_a?(Hash) ? values.values : Array(values)
      else
        Array(attributes)
      end.map { |value| normalize_column_key(value) }.reject(&:blank?)
    end

    def normalize_columns!(definitions)
      Array(definitions).map { |definition| normalize_column(definition) }
    end

    def normalize_column(definition)
      case definition
      when Symbol, String
        key = normalize_column_key(definition)
        Column.new(key: key, label: key.to_s.titleize, value: definition.to_sym)
      when Hash
        normalize_hash_column(definition)
      else
        raise InvalidExportDefinition, "column definitions must be symbols, strings, or hashes"
      end
    end

    def normalize_hash_column(definition)
      hash = definition.transform_keys(&:to_sym)
      if hash.key?(:label) || hash.key?(:value) || hash.key?(:key)
        value = hash.fetch(:value, hash[:key])
        label = hash[:label].presence || hash.fetch(:key).to_s.titleize
        key = normalize_column_key(hash[:key] || label)
      elsif definition.size == 1
        label, value = definition.first
        key = normalize_column_key(value.is_a?(Symbol) ? value : label)
      else
        raise InvalidExportDefinition, "hash column definitions require label/value"
      end

      unless value.is_a?(Symbol) || value.respond_to?(:call) || value.is_a?(String)
        raise InvalidExportDefinition, "column value must be a symbol, string, or proc"
      end

      Column.new(key: key, label: label.to_s, value: value.is_a?(String) ? value.to_sym : value)
    end

    def normalize_default_columns(values)
      keys = Array(values.presence || columns.map(&:key)).map { |value| normalize_column_key(value) }
      unknown = keys - columns.map(&:key)
      raise InvalidExportDefinition, "default columns must be registered columns" if unknown.any?

      keys
    end

    def normalize_key!(value)
      normalized = value.to_s.strip.downcase.tr("-", "_").gsub(%r{[^a-z0-9_.:/]+}, "_")
      normalized = normalized.tr(":/", ".").gsub(/\.+/, ".").gsub(/\A\.|\.\z/, "")
      raise InvalidExportDefinition, "export key is required" if normalized.blank?

      normalized
    end

    def normalize_column_key(value)
      normalized = value.to_s.strip.downcase.tr("-", "_").gsub(/[^a-z0-9_]/, "_")
      normalized = normalized.delete_prefix("_") while normalized.start_with?("_")
      normalized = normalized.delete_suffix("_") while normalized.end_with?("_")
      normalized
    end

    def normalize_strings(values)
      Array(values).flatten.compact.map(&:to_s).map(&:strip).reject(&:blank?)
    end

    def normalize_required_role!(value)
      role = value.to_s.strip
      raise InvalidExportDefinition, "required_role is required" if role.blank?

      role.to_sym
    end

    def normalize_max_rows!(value)
      integer = Integer(value)
      raise InvalidExportDefinition, "max_rows must be positive" unless integer.positive?

      integer
    rescue ArgumentError, TypeError
      raise InvalidExportDefinition, "max_rows must be an integer"
    end

    def normalize_format(value)
      format = value.to_s.strip.downcase
      raise InvalidExportDefinition, "format is required" if format.blank?

      format.to_sym
    end
  end
end
