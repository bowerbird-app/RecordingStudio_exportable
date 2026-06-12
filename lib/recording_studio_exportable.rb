# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
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

    def export(key, actor:, recording:, params: {}, context: nil)
      Exporter.call(key: key, actor: actor, recording: recording, params: params, context: context)
    end
  end
end
