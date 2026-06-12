# frozen_string_literal: true

require "active_support/core_ext/object/blank"

module RecordingStudio
  module Exportable
    module Capabilities
      module Exportable
        CAPABILITY_NAME = :exportable
        VALID_OPTION_KEYS = %i[required_role max_rows formats export_keys exports].freeze

        def self.enabled(base_or_options = nil, options = nil, on: nil, exports: nil, export_keys: nil, **legacy_options)
          base = options.nil? && base_or_options.is_a?(Hash) ? nil : base_or_options
          options = (options || (base.nil? ? base_or_options : {}) || {}).merge(legacy_options)
          options[:export_keys] ||= export_keys || exports if export_keys || exports
          validate_options!(options)

          type_name = if on
                        RecordingStudio.respond_to?(:recordable_type_name) ? RecordingStudio.recordable_type_name(on) : on.to_s
                      elsif base.respond_to?(:name)
                        base.name
                      elsif options[:base].respond_to?(:name)
                        options.delete(:base).name
                      else
                        options.delete(:on)&.to_s
                      end
          raise ArgumentError, "recordable type is required" if type_name.blank?

          normalized_options = normalize_options(options)
          RecordingStudio.enable_capability(CAPABILITY_NAME, on: type_name)
          RecordingStudio.set_capability_options(CAPABILITY_NAME, on: type_name, **normalized_options)
          true
        end

        def self.validate_options!(options)
          unknown = options.keys.map(&:to_sym) - VALID_OPTION_KEYS - %i[base on]
          raise ArgumentError, "unknown exportable option(s): #{unknown.join(', ')}" if unknown.any?

          if options.key?(:max_rows)
            begin
              Integer(options[:max_rows])
            rescue ArgumentError, TypeError
              raise ArgumentError, "max_rows must be an integer"
            end
          end
          Array(options[:formats]).each { |format| raise ArgumentError, "formats cannot be blank" if format.blank? } if options.key?(:formats)
          raise ArgumentError, "required_role cannot be blank" if options.key?(:required_role) && options[:required_role].blank?
        end

        def self.normalize_options(options)
          options = options.dup
          options[:export_keys] ||= options.delete(:exports) if options.key?(:exports)
          options[:export_keys] = Array(options[:export_keys]).map do |key|
            RecordingStudioExportable.configuration.normalize_key(key)
          end if options.key?(:export_keys)
          options[:formats] = Array(options[:formats]).map { |format| format.to_s.downcase.to_sym } if options.key?(:formats)
          options[:required_role] = options[:required_role].to_sym if options.key?(:required_role)
          options[:max_rows] = Integer(options[:max_rows]) if options.key?(:max_rows)
          options
        end
      end
    end
  end
end
