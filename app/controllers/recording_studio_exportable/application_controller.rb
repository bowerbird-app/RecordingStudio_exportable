# frozen_string_literal: true

module RecordingStudioExportable
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout "application"

    private

    def export_actor
      respond_to?(:current_user, true) ? current_user : (defined?(Current) ? Current.actor : nil)
    end
  end
end
