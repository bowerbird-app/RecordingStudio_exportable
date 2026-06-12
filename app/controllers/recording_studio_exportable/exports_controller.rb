# frozen_string_literal: true

module RecordingStudioExportable
  class ExportsController < ApplicationController
    def create
      result = RecordingStudioExportable.export(
        export_params.fetch(:export_key),
        actor: export_actor,
        recording: recording,
        params: export_params.except(:export_key, :recording_id)
      )

      send_data result.data,
                filename: result.filename,
                type: result.content_type,
                disposition: "attachment"
    end

    private

    def recording
      @recording ||= RecordingStudio::Recording.find(export_params.fetch(:recording_id))
    end

    def export_params
      params.permit(:export_key, :recording_id, :context, filters: {})
    end
  end
end
