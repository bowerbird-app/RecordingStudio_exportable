# frozen_string_literal: true

require "active_support/core_ext/object/blank"

module RecordingStudio
  module Exportable
    module Capabilities
      module Exportable
        CAPABILITY_NAME = :exportable
        VALID_OPTION_KEYS = %i[required_role max_rows formats export_keys exports].freeze

        def self.enabled(recordable = nil, export_keys: nil, exports: nil, **options)
          recordable ||= infer_recordable_from_caller
          raise ArgumentError, "recordable is required" if recordable.blank?

          options = options.dup
          options[:export_keys] ||= export_keys || exports if export_keys || exports
          validate_options!(options)

          type_name = if RecordingStudio.respond_to?(:recordable_type_name)
                        RecordingStudio.recordable_type_name(recordable)
                      elsif recordable.respond_to?(:name)
                        recordable.name
                      else
                        recordable.to_s
                      end
          raise ArgumentError, "recordable type is required" if type_name.blank?

          normalized_options = normalize_options(options)
          install_recordable_methods!(recordable)
          RecordingStudio.enable_capability(CAPABILITY_NAME, on: type_name)
          RecordingStudio.set_capability_options(CAPABILITY_NAME, on: type_name, **normalized_options)
          true
        end

        def self.infer_recordable_from_caller
          location = caller_locations(2, 10)&.find { |entry| entry.label.to_s.start_with?("<class:") }
          return if location.nil?

          class_name = location.label[/\A<class:(.+)>\z/, 1]
          return if class_name.nil? || class_name.start_with?("#<")

          Object.const_get(class_name)
        rescue NameError
          nil
        end

        def self.validate_options!(options)
          unknown = options.keys.map(&:to_sym) - VALID_OPTION_KEYS
          raise ArgumentError, "unknown exportable option(s): #{unknown.join(', ')}" if unknown.any?

          if options.key?(:max_rows)
            begin
              Integer(options[:max_rows])
            rescue ArgumentError, TypeError
              raise ArgumentError, "max_rows must be an integer"
            end
          end
          if options.key?(:formats)
            Array(options[:formats]).each do |format|
              raise ArgumentError, "formats cannot be blank" if format.blank?
            end
          end
          return unless options.key?(:required_role) && options[:required_role].blank?

          raise ArgumentError,
                "required_role cannot be blank"
        end

        def self.normalize_options(options)
          options = options.dup
          options[:export_keys] ||= options.delete(:exports) if options.key?(:exports)
          if options.key?(:export_keys)
            options[:export_keys] = Array(options[:export_keys]).map do |key|
              RecordingStudioExportable.configuration.normalize_key(key)
            end
          end
          if options.key?(:formats)
            options[:formats] = Array(options[:formats]).map do |format|
              format.to_s.downcase.to_sym
            end
          end
          options[:required_role] = options[:required_role].to_sym if options.key?(:required_role)
          options[:max_rows] = Integer(options[:max_rows]) if options.key?(:max_rows)
          options
        end

        def self.install_recordable_methods!(recordable)
          return unless recordable.respond_to?(:class_eval)

          recordable.class_eval do
            unless method_defined?(:export_keys)
              define_method(:export_keys) do
                options = if RecordingStudio.respond_to?(:capability_options)
                            RecordingStudio.capability_options(:exportable, for: self.class.name) || {}
                          else
                            {}
                          end

                if options.respond_to?(:values_at)
                  keys = options.values_at(:export_keys, "export_keys", :exports,
                                           "exports").compact.first
                end
                Array(keys).map { |key| RecordingStudioExportable.configuration.normalize_key(key) }.uniq
              end
            end

            unless method_defined?(:export_key)
              define_method(:export_key) do |key = nil|
                if key.present?
                  normalized_key = RecordingStudioExportable.configuration.normalize_key(key)
                  return unless export_keys.include?(normalized_key)

                  return RecordingStudioExportable.configuration.export_definition_for(normalized_key)
                end

                keys = export_keys
                keys.one? ? keys.first : nil
              end
            end
          end
        end
      end
    end
  end
end
