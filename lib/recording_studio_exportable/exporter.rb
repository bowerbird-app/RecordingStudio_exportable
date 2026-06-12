# frozen_string_literal: true

module RecordingStudioExportable
  class Exporter
    Result = Data.define(:data, :filename, :content_type, :row_count, :export_log)

    def self.call(...)
      new(...).call
    end

    def initialize(key:, actor:, recording:, params: {}, context: nil)
      @key = key
      @actor = actor
      @recording = recording
      @params = params || {}
      @context = context
    end

    def call
      definition = RecordingStudioExportable.configuration.fetch_export_definition!(@key)
      unless RecordingStudioExportable.configuration.export_enabled_for_recording?(definition.key, @recording)
        raise AuthorizationError, "export #{definition.key} is not enabled for this recording type"
      end

      rendered = definition.render(recording: @recording, actor: @actor, params: @params, context: @context)
      export_log = create_export_log(definition, rendered)

      Result.new(
        data: rendered.fetch(:data),
        filename: rendered.fetch(:filename),
        content_type: rendered.fetch(:content_type),
        row_count: rendered.fetch(:row_count),
        export_log: export_log
      )
    end

    private

    def create_export_log(definition, rendered)
      return unless defined?(RecordingStudioExportable::ExportLog)

      RecordingStudioExportable::ExportLog.create!(
        export_key: definition.key,
        recording: @recording,
        actor: @actor,
        filename: rendered.fetch(:filename),
        content_type: rendered.fetch(:content_type),
        row_count: rendered.fetch(:row_count)
      )
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      nil
    end
  end
end
