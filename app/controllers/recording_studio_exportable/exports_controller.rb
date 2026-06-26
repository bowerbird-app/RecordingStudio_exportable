# frozen_string_literal: true

module RecordingStudioExportable
  class ExportsController < ApplicationController
    rescue_from RecordingStudioExportable::Error, ActionController::ParameterMissing, with: :render_bad_request
    rescue_from RecordingStudioExportable::TrustedExportToken::TokenNotFound, with: :render_token_not_found
    rescue_from RecordingStudioExportable::TrustedExportToken::TokenExpired, with: :render_token_expired
    rescue_from RecordingStudioExportable::NotAuthorized, ActiveRecord::RecordNotFound, with: :render_forbidden

    def create
      result = if params[:export_token].present?
                 RecordingStudioExportable.export_from_token(
                   token_id: params[:export_token],
                   format: permitted_export_params[:format] || RecordingStudioExportable.configuration.default_format,
                   filename: permitted_export_params[:filename],
                   filters: permitted_export_params[:filters] || {},
                   controller: self
                 )
               else
                 RecordingStudioExportable.export(
                   context_recording: context_recording,
                   actor: export_actor,
                   export_key: permitted_export_params[:export_key],
                   attributes: permitted_export_params[:attributes],
                   filters: permitted_export_params[:filters] || {},
                   format: permitted_export_params[:format] || RecordingStudioExportable.configuration.default_format,
                   filename: permitted_export_params[:filename],
                   controller: self
                 )
               end

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
        :export_token,
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

    def render_token_expired(_exception)
      render :token_expired, status: :gone, formats: :html
    end

    def render_token_not_found(_exception)
      render :token_not_found, status: :not_found, formats: :html
    end
  end
end
