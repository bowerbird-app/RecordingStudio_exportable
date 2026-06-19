# frozen_string_literal: true

module RecordingStudioExportable
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout "application"

    private

    def export_actor
      resolver = RecordingStudioExportable.configuration.current_actor
      actor = resolver.call(controller: self) if resolver.respond_to?(:call)
      actor ||= current_user if respond_to?(:current_user, true)
      actor ||= Current.actor if defined?(Current) && Current.respond_to?(:actor)
      actor
    end

    def export_impersonator
      resolver = RecordingStudioExportable.configuration.current_impersonator
      impersonator = resolver.call(controller: self) if resolver.respond_to?(:call)
      impersonator ||= Current.impersonator if defined?(Current) && Current.respond_to?(:impersonator)
      impersonator
    end
  end
end
