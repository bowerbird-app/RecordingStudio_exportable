# frozen_string_literal: true

module RecordingStudioExportable
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout :recording_studio_exportable_layout

    private

    def recording_studio_exportable_layout
      configured_layout = RecordingStudioExportable.configuration.layout
      return configured_layout.call(controller: self) if configured_layout.respond_to?(:call)
      return configured_layout if configured_layout.present?

      lookup_context.exists?("layouts/flat_pack_sidebar") ? "flat_pack_sidebar" : "application"
    end

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
