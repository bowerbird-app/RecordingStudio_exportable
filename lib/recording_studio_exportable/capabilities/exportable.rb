# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/object/blank"

module RecordingStudio
  module Capabilities
    module Exportable
      extend ActiveSupport::Concern

      CAPABILITY_NAME = :exportable
      VALID_OPTION_KEYS = %i[required_role max_rows formats export_keys exports].freeze

      included do |base|
        RecordingStudio::Capabilities::Exportable.install_recordable_methods!(base)
      end

      def self.to(**options)
        prepared = prepare_options(options)
        mixin = self

        RecordingStudio::Capabilities.include_for(CAPABILITY_NAME, **prepared) do |base|
          base.include mixin unless base < mixin
        end
      end

      def self.prepare_options(options)
        options = options.dup
        options[:export_keys] ||= options.delete(:exports) if options.key?(:exports)
        validate_options!(options)
        normalize_options(options)
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
