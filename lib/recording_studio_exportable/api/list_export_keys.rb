# frozen_string_literal: true

module RecordingStudioExportable
  module Api
    class ListExportKeys
      def self.call(context)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        recording = find_recording!
        context.access_grant.authorize!(recording: recording, role: :view)
        {
          export_keys: RecordingStudioExportable.configuration.export_keys_for(
            recording: recording,
            actor: context.actor,
            context: screen_key
          )
        }
      end

      private

      attr_reader :context

      def find_recording!
        recording_id = context.recording&.id
        recording = context.access_grant.accessible_recordings.find_by(id: recording_id) if recording_id.present?
        return recording if recording

        raise RecordingStudioApi::NotFoundError, "Recording was not found in this API scope"
      end

      def screen_key
        return unless context.params.respond_to?(:[])

        context.params[:screen_key].presence
      end
    end
  end
end
