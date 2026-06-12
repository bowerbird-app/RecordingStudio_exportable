# frozen_string_literal: true

require "csv"
require "securerandom"
require "active_support/core_ext/object/blank"

module RecordingStudioExportable
  class Exporter
    Result = Data.define(:data, :filename, :content_type, :row_count, :export_log)

    DANGEROUS_CSV_PREFIX = /\A(?:[=+\-@\t\r\n]|\s+[=+\-@])/

    def self.call(...)
      new(...).call
    end

    def initialize(context_recording:, actor:, export_key: nil, attributes: nil, filters: {}, format: :csv,
                   filename: nil, controller: nil, impersonator: nil)
      @context_recording = context_recording
      @actor = actor || resolve_configured_actor(controller)
      @export_key = export_key
      @attributes = deep_hash(attributes)
      @filters = deep_hash(filters)
      @format = normalize_format(format)
      @filename = filename
      @controller = controller
      @impersonator = impersonator || resolve_configured_impersonator(controller)
    end

    def call
      definition = resolved_definition
      export_log = nil

      begin
        @capability_options = validate_capability!(definition)
        validate_authorization!(definition)
        definition.validate_context!(@context_recording, screen_key: screen_key)
        validate_format!(definition)
        selected_columns = definition.columns_for(@attributes)

        max_rows = effective_max_rows(definition)
        export_log = create_export_log(definition)
        rows = materialized_rows(definition, max_rows: max_rows)
        raise ExportTooLarge, "export #{definition.key} exceeded row limit of #{max_rows}" if rows.size > max_rows

        data = csv_for(rows, selected_columns)
        filename = resolved_filename(definition)

        mark_completed(export_log, filename: filename, row_count: rows.size)
        create_recording_studio_event(definition, filename: filename, row_count: rows.size)

        Result.new(
          data: data,
          filename: filename,
          content_type: ExportDefinition::CONTENT_TYPE,
          row_count: rows.size,
          export_log: export_log
        )
      rescue Error => e
        mark_failed(export_log, e)
        raise
      rescue StandardError => e
        mark_failed(export_log, e)
        raise
      end
    end

    private

    def configuration
      RecordingStudioExportable.configuration
    end

    def resolved_definition
      key = @export_key.presence || inferred_export_key
      configuration.fetch_export_definition!(key)
    end

    def inferred_export_key
      keys = configuration.context_export_keys_for(@context_recording)
      return keys.first if keys.size == 1

      raise UnknownExportKey, "export_key is required unless exactly one export is allowed for the context"
    end

    def validate_capability!(definition)
      options = capability_options
      unless options.present?
        raise ExportNotAllowedForContext, "exportable capability is not enabled for this context"
      end
      allowed_keys = capability_export_keys(options)
      unless allowed_keys.include?(definition.key)
        raise ExportNotAllowedForContext, "export #{definition.key} is not enabled for this context"
      end
      options
    end

    def capability_options
      return {} unless RecordingStudio.respond_to?(:capability_options)
      return {} unless @context_recording&.respond_to?(:recordable_type)

      RecordingStudio.capability_options(:exportable, for: @context_recording.recordable_type) || {}
    rescue StandardError
      {}
    end

    def capability_export_keys(options)
      keys = options.values_at(:export_keys, "export_keys", :exports, "exports").compact.first if options.respond_to?(:values_at)
      Array(keys).map { |key| configuration.normalize_key(key) }.uniq
    end

    def validate_format!(definition)
      allowed_formats = effective_formats(definition)
      raise InvalidExportFormat, "unsupported export format #{@format.inspect}" unless allowed_formats.include?(@format)
      raise InvalidExportFormat, "only csv exports are supported" unless @format == :csv
    end

    def validate_authorization!(definition)
      unless @actor.present? &&
             RecordingStudioAccessible.authorized?(actor: @actor, recording: @context_recording, role: effective_required_role(definition))
        raise NotAuthorized, "not authorized to export #{definition.key}"
      end
    end

    def effective_required_role(definition)
      (@capability_options[:required_role] || @capability_options["required_role"] || definition.required_role).to_sym
    end

    def effective_max_rows(definition)
      values = [definition.max_rows, configuration.max_rows, @capability_options[:max_rows], @capability_options["max_rows"]].compact
      values.map { |value| Integer(value) }.min
    end

    def effective_formats(definition)
      capability_formats = @capability_options[:formats] || @capability_options["formats"]
      return definition.formats unless capability_formats.present?

      definition.formats & Array(capability_formats).map { |format| format.to_s.downcase.to_sym }
    end

    def materialized_rows(definition, max_rows:)
      rows = definition.resolve_rows(
        context_recording: @context_recording,
        actor: @actor,
        attributes: @attributes,
        filters: @filters,
        format: @format,
        controller: @controller
      )

      return [] if rows.nil?
      return rows.limit(max_rows + 1).to_a if rows.respond_to?(:limit)
      return rows.take(max_rows + 1) if rows.respond_to?(:take)
      return rows.each.take(max_rows + 1) if rows.respond_to?(:each)

      Array(rows).take(max_rows + 1)
    end

    def csv_for(rows, columns)
      csv = CSV.generate do |writer|
        writer << columns.map { |column| csv_safe(column.label) }
        rows.each do |row|
          writer << columns.each_with_index.map { |column, index| csv_safe(value_for(row, column, index)) }
        end
      end

      configuration.include_bom ? "\uFEFF#{csv}" : csv
    end

    def value_for(row, column, index)
      value = if column.value.respond_to?(:call)
                column.value.call(row)
              elsif row.is_a?(Hash)
                fetch_hash_value(row, column)
              elsif row.is_a?(Array)
                row[index]
              else
                row.public_send(column.value)
              end

      value
    end

    def fetch_hash_value(row, column)
      return row[column.value] if row.key?(column.value)
      return row[column.value.to_s] if row.key?(column.value.to_s)
      return row[column.key] if row.key?(column.key)
      return row[column.key.to_s] if row.key?(column.key.to_s)
      return row[column.label] if row.key?(column.label)

      nil
    end

    def csv_safe(value)
      return value unless value.is_a?(String)

      value.match?(DANGEROUS_CSV_PREFIX) ? "'#{value}" : value
    end

    def resolved_filename(definition)
      requested = @filename if configuration.allow_request_filename_override
      sanitize_filename(requested.presence || definition.filename_for(
        context_recording: @context_recording,
        actor: @actor,
        attributes: @attributes,
        filters: @filters,
        format: @format
      ))
    end

    def sanitize_filename(value)
      basename = value.to_s.strip.presence || ExportDefinition::DEFAULT_FILENAME
      cleaned = basename.each_char.map { |char| filename_character?(char) ? char : "-" }.join
      cleaned = cleaned.gsub(/-+/, "-").delete_prefix(".").delete_prefix("-").delete_suffix(".").delete_suffix("-")
      cleaned = ExportDefinition::DEFAULT_FILENAME if cleaned.blank?
      cleaned = cleaned.sub(/\.csv\z/i, "") if cleaned.downcase.end_with?(".csv")
      "#{cleaned.first(116)}.csv"
    end

    def filename_character?(char)
      char.between?("A", "Z") ||
        char.between?("a", "z") ||
        char.between?("0", "9") ||
        [".", "_", "-"].include?(char)
    end

    def create_export_log(definition)
      return unless defined?(RecordingStudioExportable::ExportLog)

      RecordingStudioExportable::ExportLog.create!(
        export_key: definition.key,
        context_recording: @context_recording,
        actor: @actor,
        impersonator: @impersonator,
        status: :running,
        content_type: ExportDefinition::CONTENT_TYPE,
        row_count: 0,
        filters: sanitized_filters_for_log
      )
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, ActiveRecord::UnknownAttributeError
      nil
    end

    def mark_completed(export_log, filename:, row_count:)
      return unless export_log

      export_log.update!(status: :completed, filename: filename, row_count: row_count)
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    def mark_failed(export_log, exception)
      return unless export_log

      export_log.update!(
        status: :failed,
        error_class: exception.class.name,
        error_message: sanitized_error_message(exception)
      )
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    def create_recording_studio_event(definition, filename:, row_count:)
      return unless defined?(RecordingStudio::Event) && @context_recording

      recordable = @context_recording.respond_to?(:recordable) ? @context_recording.recordable : nil
      RecordingStudio::Event.create!(
        action: "exported",
        recording_id: @context_recording.id,
        recordable_type: recordable&.class&.name || @context_recording.recordable_type,
        recordable_id: (recordable.id if recordable.respond_to?(:id)) ||
          (@context_recording.recordable_id if @context_recording.respond_to?(:recordable_id)),
        actor_type: @actor&.class&.name,
        actor_id: @actor.respond_to?(:id) ? @actor.id : nil,
        impersonator_type: @impersonator&.class&.name,
        impersonator_id: @impersonator.respond_to?(:id) ? @impersonator.id : nil,
        metadata: {
          export_key: definition.key,
          filename: filename,
          row_count: row_count
        }
      )
    rescue ActiveRecord::ActiveRecordError, NoMethodError
      nil
    end

    def resolve_configured_actor(controller)
      resolver = configuration.current_actor
      resolver.respond_to?(:call) ? resolver.call(controller: controller) : nil
    end

    def resolve_configured_impersonator(controller)
      resolver = configuration.current_impersonator
      resolver.respond_to?(:call) ? resolver.call(controller: controller) : nil
    end

    def normalize_format(value)
      (value.presence || configuration.default_format).to_s.downcase.to_sym
    end

    def screen_key
      @filters[:screen_key] || @filters["screen_key"] || @attributes[:screen_key] || @attributes["screen_key"]
    end

    def sanitized_filters_for_log
      sanitizer = configuration.filter_log_sanitizer
      sanitizer.respond_to?(:call) ? sanitizer.call(@filters) : @filters
    rescue StandardError
      {}
    end

    def sanitized_error_message(exception)
      return exception.message.to_s.first(500) if exception.is_a?(RecordingStudioExportable::Error)

      "Export failed"
    end

    def deep_hash(value)
      case value
      when nil
        {}
      when Hash
        value.each_with_object({}) { |(key, child), result| result[key] = deep_hash_value(child) }
      else
        return deep_hash(value.to_unsafe_h) if defined?(ActionController::Parameters) &&
                                              value.is_a?(ActionController::Parameters)

        value
      end
    end

    def deep_hash_value(value)
      case value
      when Hash
        deep_hash(value)
      when Array
        value.map { |child| deep_hash_value(child) }
      else
        return deep_hash(value) if defined?(ActionController::Parameters) && value.is_a?(ActionController::Parameters)

        value
      end
    end
  end
end
