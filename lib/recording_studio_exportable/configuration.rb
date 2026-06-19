# frozen_string_literal: true

require "monitor"
require "active_support/parameter_filter"
require "active_support/core_ext/object/blank"
require_relative "hooks"

module RecordingStudioExportable
  class Configuration
    DEFAULT_MAX_ROWS = 50_000

    attr_accessor :current_actor, :current_impersonator, :default_format, :default_required_role,
                  :max_rows, :include_bom, :allow_request_filename_override,
                  :filter_log_sanitizer, :context_export_keys_resolver
    attr_reader :export_definitions, :hooks

    def initialize
      @current_actor = lambda do |controller: nil|
        (controller&.send(:current_user) if controller&.respond_to?(:current_user, true)) ||
          (defined?(Current) && Current.respond_to?(:actor) ? Current.actor : nil)
      end
      @current_impersonator = lambda { |*|
        defined?(Current) && Current.respond_to?(:impersonator) ? Current.impersonator : nil
      }
      @default_format = :csv
      @default_required_role = :view
      @max_rows = DEFAULT_MAX_ROWS
      @include_bom = false
      @allow_request_filename_override = false
      @filter_log_sanitizer = method(:default_filter_log_sanitizer)
      @context_export_keys_resolver = method(:default_context_export_keys_for)
      @export_definitions = {}
      @hooks = Hooks.new
      @mutex = Monitor.new
    end

    def default_row_limit
      max_rows
    end

    def default_row_limit=(value)
      self.max_rows = value
    end

    def register_export(key, replace: false, **options, &)
      options = options.dup
      options[:required_role] = default_required_role unless options.key?(:required_role)
      options[:max_rows] = max_rows unless options.key?(:max_rows) || options.key?(:row_limit)
      options[:formats] = [default_format] unless options.key?(:formats)

      definition = ExportDefinition.new(
        key: normalize_key(key),
        **options,
        &
      )

      @mutex.synchronize do
        if @export_definitions.key?(definition.key) && !replace
          existing = @export_definitions.fetch(definition.key)
          return existing if existing.equivalent_to?(definition)

          unless test_environment?
            warn "RecordingStudioExportable export #{definition.key.inspect} replaced duplicate registration"
          end
        end

        @export_definitions[definition.key] = definition
      end

      definition
    end
    alias export register_export

    def replace_export(key, **, &)
      register_export(key, replace: true, **, &)
    end

    def export_definition_for(key)
      @mutex.synchronize { @export_definitions[normalize_key(key)] }
    end
    alias export_definition export_definition_for

    def fetch_export_definition!(key)
      export_definition_for(key) || raise(UnknownExportKey, "unknown export key #{normalize_key(key).inspect}")
    end

    def context_export_keys_for(context_recording)
      keys = (context_export_keys_resolver.call(context_recording) if context_export_keys_resolver.respond_to?(:call))

      Array(keys).map { |key| normalize_key(key) }.uniq
    rescue StandardError
      []
    end

    def export_enabled_for_recording?(key, recording)
      capability_export_keys_for(recording).include?(normalize_key(key))
    end

    def export_keys_for(recording:, actor:, context: nil)
      capability_export_keys_for(recording).select do |key|
        definition = export_definition_for(key)
        next false unless definition&.valid_context?(recording, screen_key: context)
        next false unless actor.present?

        RecordingStudioAccessible.authorized?(
          actor: actor,
          recording: recording,
          role: effective_required_role(definition, recording)
        )
      end.sort
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
        default_format: default_format,
        default_required_role: default_required_role,
        max_rows: max_rows,
        include_bom: include_bom,
        allow_request_filename_override: allow_request_filename_override,
        export_definitions: @export_definitions.keys.sort,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    private

    def default_context_export_keys_for(context_recording)
      return [] unless context_recording

      recordable = context_recording.recordable if context_recording.respond_to?(:recordable)
      keys = if recordable&.respond_to?(:export_keys)
               recordable.export_keys
             elsif recordable&.class&.const_defined?(:EXPORT_KEYS)
               recordable.class::EXPORT_KEYS
             elsif recordable&.respond_to?(:export_key)
               recordable.export_key
             else
               []
             end

      Array(keys)
    end

    def capability_export_keys_for(context_recording)
      options = capability_options_for(context_recording)
      return [] unless options.present?

      if options.respond_to?(:values_at)
        keys = options.values_at(:export_keys, "export_keys", :exports,
                                 "exports").compact.first
      end
      Array(keys).map { |key| normalize_key(key) }.uniq
    end

    def default_filter_log_sanitizer(filters)
      ActiveSupport::ParameterFilter.new(filter_parameters).filter(filters || {})
    end

    def filter_parameters
      rails_filters = if defined?(Rails) && Rails.respond_to?(:application) && Rails.application&.config
                        Rails.application.config.filter_parameters
                      end
      Array(rails_filters).presence || %i[
        password passphrase secret token api_key access_key authorization credential
      ]
    end

    def effective_required_role(definition, context_recording)
      options = capability_options_for(context_recording)
      (options&.values_at(:required_role, "required_role")&.compact&.first || definition.required_role).to_sym
    end

    def capability_options_for(context_recording)
      type_name = context_recording.respond_to?(:recordable_type) ? context_recording.recordable_type : nil
      return if type_name.blank? || !RecordingStudio.respond_to?(:capability_options)

      RecordingStudio.capability_options(:exportable, for: type_name)
    end

    def test_environment?
      defined?(Rails) && Rails.respond_to?(:env) && Rails.env.test?
    end
  end
end
