# frozen_string_literal: true

module RecordingStudioExportable
  module Api
    class ExportRecording
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = find_recording!
        definition = fetch_definition!
        authorize_export!(recording, definition)
        serialize(export!(recording))
      end

      private

      attr_reader :context

      def find_recording!
        recording_id = context.recording&.id
        recording = accessible_recordings.find_by(id: recording_id) if recording_id.present?
        return recording if recording

        raise RecordingStudioApi::NotFoundError, "Recording was not found in this API scope"
      end

      def accessible_recordings
        context.access_grant.accessible_recordings
      end

      def fetch_definition!
        RecordingStudioExportable.configuration.fetch_export_definition!(parameter_value(:export_key))
      rescue UnknownExportKey => e
        raise invalid_input_error(e.message)
      end

      def authorize_export!(recording, definition)
        context.access_grant.authorize!(recording: recording, role: export_role(definition, recording))
      end

      def export_role(definition, recording)
        options = RecordingStudioExportable.configuration.capability_options_for(recording) || {}
        (
          definition.required_role ||
          options[:required_role] ||
          options["required_role"] ||
          RecordingStudioExportable.configuration.default_required_role ||
          :view
        ).to_sym
      end

      def export!(recording)
        RecordingStudioExportable.export(
          context_recording: recording,
          actor: context.actor,
          export_key: parameter_value(:export_key),
          attributes: parameter_value(:attributes),
          filters: parameter_value(:filters) || {},
          format: parameter_value(:format) || RecordingStudioExportable.configuration.default_format,
          filename: parameter_value(:filename)
        )
      rescue NotAuthorized => e
        raise RecordingStudioApi::AuthorizationError, e.message
      rescue UnknownExportKey, ExportNotAllowedForContext, InvalidExportFormat,
             InvalidExportColumns, InvalidExportAttributes => e
        raise invalid_input_error(e.message)
      rescue ExportTooLarge => e
        raise invalid_input_error(e.message)
      end

      def serialize(result)
        {
          export_key: parameter_value(:export_key),
          filename: result.filename,
          content_type: result.content_type,
          row_count: result.row_count,
          data: result.data
        }
      end

      def parameter_value(key)
        return unless context.params.respond_to?(:[])

        context.params[key].presence
      end

      def invalid_input_error(message)
        RecordingStudioApi::InvalidActionInputError.new(message, details: [message])
      end
    end
  end
end
