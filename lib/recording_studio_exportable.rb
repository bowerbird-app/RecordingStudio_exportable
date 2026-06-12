# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
require "flat_pack"
require "recording_studio_exportable/version"
require "recording_studio_exportable/errors"
require "recording_studio_exportable/export_definition"
require "recording_studio_exportable/configuration"
require "recording_studio_exportable/exporter"
require "recording_studio_exportable/capabilities/exportable"
require "recording_studio_exportable/services/base_service"
require "recording_studio_exportable/services/example_service"
require "recording_studio_exportable/engine"

module RecordingStudioExportable
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def export(context_recording:, actor:, export_key: nil, attributes: nil, filters: {}, format: :csv,
               filename: nil, controller: nil)
      Exporter.call(
        context_recording: context_recording,
        actor: actor,
        export_key: export_key,
        attributes: attributes,
        filters: filters,
        format: format,
        filename: filename,
        controller: controller
      )
    end
  end
end
