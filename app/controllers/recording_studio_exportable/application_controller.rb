# frozen_string_literal: true

module RecordingStudioExportable
  class ApplicationController < ActionController::Base
    include RecordingStudio::ControllerLayout

    protect_from_forgery with: :exception
    recording_studio_layout { RecordingStudioExportable.configuration.layout }

    private

    def export_actor
      RecordingStudioExportable.configuration.resolve_actor(self)
    end

    def export_impersonator
      resolver = RecordingStudioExportable.configuration.current_impersonator
      impersonator = resolver.call(controller: self) if resolver.respond_to?(:call)
      impersonator ||= Current.impersonator if defined?(Current) && Current.respond_to?(:impersonator)
      impersonator
    end
  end
end
