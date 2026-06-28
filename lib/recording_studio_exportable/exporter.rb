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
                   filename: nil, controller: nil, impersonator: nil,
                   trusted_export: false, rows: nil, columns: nil, trusted_source: nil,
                   screen_identifier: nil)
      @context_recording = context_recording
      @actor = actor || resolve_configured_actor(controller)
      @export_key = export_key
      @attributes = deep_hash(attributes)
      @filters = deep_hash(filters)
      @format = normalize_format(format)
      @filename = filename
      @controller = controller
      @impersonator = impersonator || resolve_configured_impersonator(controller)
      @trusted_export = trusted_export
      @rows = rows
      @columns = columns
      @trusted_source = trusted_source
      @screen_identifier = screen_identifier
    end

    def call
      @trusted_export ? call_trusted_export : call_full_export
    end

    def call_full_export
      definition = resolved_definition
      logged_filters = sanitized_filters_for_log
      export_log = create_export_log(definition: definition, filters: logged_filters)

      begin
        @capability_options = validate_capability!(definition)
        validate_context_export_key!(definition)
        definition.validate_context!(@context_recording, screen_key: screen_key)
        validate_format!(definition)
        validate_authorization!(definition)
        selected_columns = definition.columns_for(@attributes)
        definition.validate_attributes!(@attributes)

        max_rows = effective_max_rows(definition)
        rows = materialized_rows(definition, max_rows: max_rows)
        raise ExportTooLarge, "export #{definition.key} exceeded row limit of #{max_rows}" if rows.size > max_rows

        data = csv_for(rows, selected_columns)
        filename = resolved_filename(definition)
        selected_attributes = selected_columns.map(&:key)
        metadata = {
          export_key: definition.key,
          format: @format,
          attributes: selected_attributes,
          filters: logged_filters,
          row_count: rows.size,
          filename: filename
        }

        mark_completed(
          export_log,
          filename: filename,
          row_count: rows.size,
          byte_size: data.bytesize,
          selected_attributes: selected_attributes,
          metadata: metadata
        )
        create_recording_studio_event(
          definition,
          export_log: export_log,
          filename: filename,
          row_count: rows.size,
          selected_attributes: selected_attributes,
          logged_filters: logged_filters
        )

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

    def call_trusted_export
      raise ArgumentError, "rows is required for trusted export" if @rows.nil?
      raise ArgumentError, "columns is required for trusted export" if @columns.nil?
      raise ArgumentError, "actor is required for trusted export" if @actor.nil?

      export_key = @export_key.presence || "trusted.#{SecureRandom.hex(4)}"
      definition = build_anonymous_definition(export_key, @columns)
      logged_filters = sanitized_filters_for_log
      export_log = create_export_log(definition: definition, filters: logged_filters)

      begin
        validate_trusted_format!
        max_rows = effective_max_rows(nil)
        rows = materialized_trusted_rows(resolved_trusted_rows, max_rows: max_rows)
        raise ExportTooLarge, "export exceeded row limit of #{max_rows}" if rows.size > max_rows

        data = csv_for(rows, @columns)
        filename = resolved_trusted_filename(export_key)
        selected_attributes = @columns.map(&:key)
        metadata = {
          export_key: export_key,
          format: @format,
          attributes: selected_attributes,
          filters: logged_filters,
          row_count: rows.size,
          filename: filename,
          trusted_source: @trusted_source,
          screen_identifier: @screen_identifier
        }

        mark_completed(
          export_log,
          filename: filename,
          row_count: rows.size,
          byte_size: data.bytesize,
          selected_attributes: selected_attributes,
          metadata: metadata
        )
        create_trusted_recording_studio_event(
          definition,
          export_log: export_log,
          filename: filename,
          row_count: rows.size,
          selected_attributes: selected_attributes,
          logged_filters: logged_filters
        )

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
      raise ExportNotAllowedForContext, "exportable capability is not enabled for this context" unless options.present?

      allowed_keys = capability_export_keys(options)
      unless allowed_keys.include?(definition.key)
        raise ExportNotAllowedForContext, "export #{definition.key} is not enabled for this context"
      end

      options
    end

    def validate_context_export_key!(definition)
      allowed_keys = configuration.context_export_keys_for(@context_recording)
      return if allowed_keys.include?(definition.key)

      raise ExportNotAllowedForContext, "export #{definition.key} is not allowed for this context"
    end

    def capability_options
      return {} unless RecordingStudio.respond_to?(:capability_options)
      return {} unless @context_recording.respond_to?(:recordable_type)

      RecordingStudio.capability_options(:exportable, for: @context_recording.recordable_type) || {}
    rescue StandardError
      {}
    end

    def capability_export_keys(options)
      if options.respond_to?(:values_at)
        keys = options.values_at(:export_keys, "export_keys", :exports,
                                 "exports").compact.first
      end
      Array(keys).map { |key| configuration.normalize_key(key) }.uniq
    end

    def validate_format!(definition)
      allowed_formats = effective_formats(definition)
      raise InvalidExportFormat, "unsupported export format #{@format.inspect}" unless allowed_formats.include?(@format)
      raise InvalidExportFormat, "only csv exports are supported" unless @format == :csv
    end

    def validate_authorization!(definition)
      unless @actor.present? &&
             RecordingStudioAccessible.authorized?(actor: @actor, recording: @context_recording,
                                                   role: effective_required_role(definition))
        raise NotAuthorized, "not authorized to export #{definition.key}"
      end
    end

    def effective_required_role(definition)
      (
        definition.required_role ||
        @capability_options[:required_role] ||
        @capability_options["required_role"] ||
        configuration.default_required_role ||
        :view
      ).to_sym
    end

    def effective_max_rows(definition)
      definition_max_rows = definition&.max_rows
      explicit_definition_max_rows = definition_max_rows if definition_max_rows != Configuration::DEFAULT_MAX_ROWS

      Integer(
        explicit_definition_max_rows ||
          @capability_options&.dig(:max_rows) ||
          @capability_options&.dig("max_rows") ||
          configuration.max_rows ||
          definition_max_rows ||
          Configuration::DEFAULT_MAX_ROWS
      )
    end

    def effective_formats(definition)
      capability_formats = @capability_options&.dig(:formats) || @capability_options&.dig("formats")
      return definition.formats unless capability_formats.present?

      definition.formats & Array(capability_formats).map { |format| format.to_s.downcase.to_sym }
    end

    def build_anonymous_definition(export_key, columns)
      ExportDefinition.new(
        key: export_key,
        columns: columns.map do |column|
          column.respond_to?(:to_h) ? column.to_h : { key: column.key, label: column.label, value: column.value }
        end,
        resolver: ->(**) { raise "Anonymous definition — use trusted_export path" },
        required_role: :view,
        max_rows: 1
      )
    end

    def validate_trusted_format!
      raise InvalidExportFormat, "unsupported export format #{@format.inspect}" unless @format == :csv
    end

    def materialized_trusted_rows(rows, max_rows:)
      return [] if rows.nil?
      return rows.take(max_rows + 1) if rows.respond_to?(:take)
      return rows.each.take(max_rows + 1) if rows.respond_to?(:each)

      Array(rows).take(max_rows + 1)
    end

    def resolved_trusted_rows
      @rows.respond_to?(:call) ? @rows.call : @rows
    end

    def resolved_trusted_filename(export_key)
      requested = @filename if configuration.allow_request_filename_override
      fallback = export_key.parameterize.presence || "export"
      sanitize_filename(requested.presence || fallback)
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
      if column.value.respond_to?(:call)
        column.value.call(row)
      elsif row.is_a?(Hash)
        fetch_hash_value(row, column)
      elsif row.is_a?(Array)
        row[index]
      else
        row.public_send(column.value)
      end
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
      return value if value.nil?

      string_value = value.to_s
      string_value.match?(DANGEROUS_CSV_PREFIX) ? "'#{string_value}" : value
    end

    def resolved_filename(definition)
      requested = @filename if configuration.allow_request_filename_override
      definition_name = definition.filename_for(
        context_recording: @context_recording,
        actor: @actor,
        attributes: @attributes,
        filters: @filters,
        format: @format
      )
      fallback_name = context_recording_fallback_filename
      sanitize_filename(requested.presence || definition_name.presence || fallback_name)
    end

    def context_recording_fallback_filename
      recordable = @context_recording&.recordable
      return unless recordable.respond_to?(:export_filename)

      recordable.export_filename(format: @format)
    rescue StandardError
      nil
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

    def create_export_log(definition:, filters:)
      return unless defined?(RecordingStudioExportable::ExportLog)

      recordable = @context_recording.respond_to?(:recordable) ? @context_recording.recordable : nil
      context_recording_value = @context_recording.is_a?(RecordingStudio::Recording) ? @context_recording : nil

      attrs = {
        export_key: definition.key,
        context_recording: context_recording_value,
        context_recordable_type: recordable&.class&.name,
        context_recordable_id: (recordable.id if recordable.respond_to?(:id)),
        screen_key: screen_key,
        format: @format,
        attributes: [],
        metadata: {},
        actor: @actor,
        impersonator: @impersonator,
        status: :running,
        content_type: ExportDefinition::CONTENT_TYPE,
        row_count: 0,
        byte_size: 0,
        filters: filters,
        started_at: Time.current
      }

      # Filter out any keys with nil values that would be rejected by create!
      filtered_attrs = filter_known_log_attributes(attrs)

      RecordingStudioExportable::ExportLog.create!(**filtered_attrs)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError,
           ActiveRecord::UnknownAttributeError, ActiveRecord::AssociationTypeMismatch
      nil
    end

    def mark_completed(export_log, filename:, row_count:, byte_size:, selected_attributes:, metadata:)
      return unless export_log

      attrs = {
        status: :completed,
        filename: filename,
        row_count: row_count,
        byte_size: byte_size,
        attributes: selected_attributes,
        metadata: metadata,
        completed_at: Time.current
      }
      export_log.update!(**filter_known_log_attributes(attrs, record: export_log))
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    def mark_failed(export_log, exception)
      return unless export_log

      attrs = {
        status: :failed,
        error_class: exception.class.name,
        error_message: sanitized_error_message(exception),
        failed_at: Time.current
      }
      export_log.update!(**filter_known_log_attributes(attrs, record: export_log))
    rescue ActiveRecord::ActiveRecordError
      nil
    end

    def filter_known_log_attributes(attrs, record: nil)
      if record
        attrs.select do |key, _|
          record.has_attribute?(key) || (key == :context_recording && record.respond_to?(:context_recording=))
        end
      else
        column_names = RecordingStudioExportable::ExportLog.column_names
        attrs.select { |key, _| column_names.include?(key.to_s) || key == :context_recording }
      end
    rescue StandardError
      attrs
    end

    def create_recording_studio_event(definition, export_log:, filename:, row_count:, selected_attributes:,
                                      logged_filters:)
      return unless @context_recording

      recordable = @context_recording.respond_to?(:recordable) ? @context_recording.recordable : nil

      if RecordingStudio.respond_to?(:root_recording_or_self)
        root = RecordingStudio.root_recording_or_self(@context_recording)
        if root.respond_to?(:log_event)
          root.log_event(
            @context_recording,
            action: "exported",
            actor: @actor,
            impersonator: @impersonator,
            metadata: {
              export_log_id: export_log&.id,
              export_key: definition.key,
              format: @format,
              attributes: selected_attributes,
              filters: logged_filters,
              filename: filename,
              row_count: row_count
            }
          )
          return
        end
      end

      return unless defined?(RecordingStudio::Event)

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
          export_log_id: export_log&.id,
          export_key: definition.key,
          format: @format,
          attributes: selected_attributes,
          filters: logged_filters,
          filename: filename,
          row_count: row_count
        }
      )
    rescue ActiveRecord::ActiveRecordError, NoMethodError
      nil
    end

    def create_trusted_recording_studio_event(definition, export_log:, filename:, row_count:,
                                              selected_attributes:, logged_filters:)
      return unless @context_recording

      recordable = @context_recording.respond_to?(:recordable) ? @context_recording.recordable : nil
      metadata = {
        export_log_id: export_log&.id,
        export_key: definition.key,
        format: @format,
        attributes: selected_attributes,
        filters: logged_filters,
        filename: filename,
        row_count: row_count,
        trusted_source: @trusted_source,
        screen_identifier: @screen_identifier
      }

      if RecordingStudio.respond_to?(:root_recording_or_self)
        root = RecordingStudio.root_recording_or_self(@context_recording)
        if root.respond_to?(:log_event)
          root.log_event(
            @context_recording,
            action: "exported",
            actor: @actor,
            impersonator: @impersonator,
            metadata: metadata
          )
          return
        end
      end

      return unless defined?(RecordingStudio::Event)

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
        metadata: metadata
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
        value.transform_values { |child| deep_hash_value(child) }
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
