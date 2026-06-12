# frozen_string_literal: true

module RecordingStudioExportable
  class ExportsController < ApplicationController
    rescue_from RecordingStudioExportable::Error, ActionController::ParameterMissing, with: :render_bad_request
    rescue_from RecordingStudioExportable::NotAuthorized, ActiveRecord::RecordNotFound, with: :render_forbidden

    def create
      result = RecordingStudioExportable.export(
        context_recording: context_recording,
        actor: export_actor,
        export_key: permitted_export_params[:export_key],
        attributes: permitted_export_params[:attributes],
        filters: permitted_export_params[:filters] || {},
        format: permitted_export_params[:format] || RecordingStudioExportable.configuration.default_format,
        filename: permitted_export_params[:filename],
        controller: self
      )

      send_data result.data,
                filename: result.filename,
                type: result.content_type,
                disposition: "attachment"
    end

    private

    def context_recording
      @context_recording ||= RecordingStudio::Recording.find(permitted_export_params.fetch(:context_recording_id))
    end

    def permitted_export_params
      @permitted_export_params ||= params.permit(
        :context_recording_id,
        :export_key,
        :format,
        :filename,
        attributes: [:screen_key, { columns: [] }],
        filters: {}
      )
    end

    def render_forbidden(_exception)
      render plain: "Export is not available", status: :forbidden
    end

    def render_bad_request(_exception)
      render plain: "Export request is invalid", status: :bad_request
    end
  end
end
