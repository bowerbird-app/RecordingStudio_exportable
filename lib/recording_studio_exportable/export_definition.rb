# frozen_string_literal: true

require "csv"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/inflections"

module RecordingStudioExportable
  class ExportDefinition
    CONTENT_TYPE = "text/csv; charset=utf-8"
    DEFAULT_FILENAME = "recording-export.csv"

    attr_reader :key, :label, :description, :headers, :row_limit, :required_role, :filename, :context_key

    def initialize(key:, label: nil, description: nil, headers: nil, row_limit: nil, required_role: :view,
                   filename: nil, context_key: nil, exporter: nil, &block)
      @key = normalize_key!(key)
      @label = label.presence || @key.titleize
      @description = description.to_s
      @headers = normalize_headers!(headers)
      @row_limit = normalize_row_limit!(row_limit)
      @required_role = normalize_required_role!(required_role)
      @filename = filename.presence || DEFAULT_FILENAME
      @context_key = normalize_context_key(context_key)
      @exporter = exporter || block

      validate!
    end

    def equivalent_to?(other)
      other.is_a?(self.class) &&
        key == other.key &&
        label == other.label &&
        description == other.description &&
        headers == other.headers &&
        row_limit == other.row_limit &&
        required_role == other.required_role &&
        filename == other.filename &&
        context_key == other.context_key &&
        @exporter == other.instance_variable_get(:@exporter)
    end

    def available_for?(recording:, actor:, context: nil)
      context_matches?(context) && authorized?(actor: actor, recording: recording)
    end

    def authorized?(actor:, recording:)
      actor.present? &&
        recording.present? &&
        RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: required_role)
    end

    def render(recording:, actor:, params: {}, context: nil)
      raise AuthorizationError, "not authorized to export #{key}" unless available_for?(
        recording: recording,
        actor: actor,
        context: context
      )

      rows = rows_for(recording: recording, actor: actor, params: params, context: context)
      csv_rows = []
      enumerable_rows(rows).each_with_index do |row, index|
        raise RowLimitExceeded, "export #{key} exceeded row limit of #{row_limit}" if index >= row_limit

        csv_rows << normalize_row(row)
      end

      data = CSV.generate do |csv|
        csv << headers
        csv_rows.each { |row| csv << row }
      end

      {
        data: data,
        filename: sanitized_filename(recording: recording, params: params),
        content_type: CONTENT_TYPE,
        row_count: csv_rows.size
      }
    end

    private

    def validate!
      raise InvalidExportDefinition, "exporter must respond to call" unless @exporter.respond_to?(:call)
      raise InvalidExportDefinition, "headers are required" if headers.empty?
    end

    def context_matches?(context)
      context_key.nil? || normalize_context_key(context) == context_key
    end

    def rows_for(recording:, actor:, params:, context:)
      @exporter.call(recording: recording, actor: actor, params: params.to_h, context: context)
    end

    def normalize_row(row)
      return headers.map { |header| row[header] || row[header.to_s] || row[header.to_sym] } if row.is_a?(Hash)

      Array(row)
    end

    def enumerable_rows(rows)
      return [] if rows.nil?
      return rows if rows.respond_to?(:each)

      Array(rows)
    end

    def sanitized_filename(recording:, params:)
      value = if filename.respond_to?(:call)
                filename.call(recording: recording, params: params.to_h)
              else
                filename
              end
      basename = value.to_s.presence || DEFAULT_FILENAME
      basename = clean_filename(basename)
      basename = DEFAULT_FILENAME if basename.blank?
      basename = "#{basename}.csv" unless basename.downcase.end_with?(".csv")
      basename.first(120)
    end

    def clean_filename(value)
      cleaned = +""
      previous_dash = false
      value.each_char do |char|
        if filename_character?(char)
          cleaned << char
          previous_dash = char == "-"
        elsif !previous_dash
          cleaned << "-"
          previous_dash = true
        end
      end
      cleaned.delete_prefix(".").delete_prefix("-").delete_suffix(".").delete_suffix("-")
    end

    def filename_character?(char)
      char.between?("A", "Z") ||
        char.between?("a", "z") ||
        char.between?("0", "9") ||
        [".", "_", "-"].include?(char)
    end

    def normalize_key!(value)
      normalized = value.to_s.strip.downcase.tr("-", "_").gsub(%r{[^a-z0-9_.:/]+}, "_")
      normalized = normalized.tr(":/", ".").gsub(/\.+/, ".").gsub(/\A\.|\.\z/, "")
      raise InvalidExportDefinition, "export key is required" if normalized.blank?

      normalized
    end

    def normalize_headers!(values)
      Array(values).map { |value| value.to_s.strip }.reject(&:blank?)
    end

    def normalize_row_limit!(value)
      integer = Integer(value || Configuration::DEFAULT_ROW_LIMIT)
      raise InvalidExportDefinition, "row_limit must be positive" unless integer.positive?

      integer
    rescue ArgumentError, TypeError
      raise InvalidExportDefinition, "row_limit must be an integer"
    end

    def normalize_required_role!(value)
      role = value.to_s.strip
      raise InvalidExportDefinition, "required_role is required" if role.blank?

      role.to_sym
    end

    def normalize_context_key(value)
      value.to_s.strip.presence&.underscore
    end
  end
end
