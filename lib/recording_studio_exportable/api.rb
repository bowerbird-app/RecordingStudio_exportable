# frozen_string_literal: true

require "recording_studio_exportable/api/export_recording"
require "recording_studio_exportable/api/list_export_keys"

module RecordingStudioExportable
  module Api
    ACTION_VERSION = "1.0.0"

    class << self
      def register_capability_action!
        return unless recording_studio_api_available?

        RecordingStudioApi.configuration.each_api do |api_definition|
          register_actions_for(api_definition.name)
        end
      end

      private

      def register_actions_for(api_name)
        action_descriptors.each do |descriptor|
          next if RecordingStudioApi.capability_action(descriptor[:name], api: api_name)

          RecordingStudioApi.register_capability_action(
            descriptor[:name],
            api: api_name,
            **capability_action_options(descriptor)
          )
        end
      end

      def action_descriptors
        [
          {
            name: :export,
            http_verb: :post,
            handler: ExportRecording,
            required_role: :view,
            version_notes: ["Exportable-owned export action"],
            input_contract: { reject_unknown: false, fields: {} },
            openapi: {
              summary: "Export this recording as CSV.",
              description: "Runs the same RecordingStudioExportable.export path as the UI for this recording.",
              responses: {
                "200" => { description: "CSV export completed." },
                "403" => { description: "API access is not authorized to export this recording." },
                "404" => { description: "Recording was not found in this API scope." },
                "422" => { description: "Export request is invalid." }
              }
            }
          },
          {
            name: :export_keys,
            http_verb: :get,
            handler: ListExportKeys,
            required_role: :view,
            version_notes: ["Exportable-owned export key listing"],
            input_contract: { reject_unknown: false, fields: {} },
            openapi: {
              summary: "List export keys this grant may use for this recording.",
              description: "Returns the keys Configuration#export_keys_for allows for the grant actor on this recording.",
              responses: {
                "200" => { description: "Allowed export keys returned." },
                "403" => { description: "API access is not authorized to view this recording." },
                "404" => { description: "Recording was not found in this API scope." }
              }
            }
          }
        ]
      end

      def capability_action_options(descriptor)
        {
          capability: :exportable,
          version: ACTION_VERSION,
          version_notes: descriptor[:version_notes],
          http_verb: descriptor[:http_verb],
          scope: :member,
          required_role: descriptor[:required_role],
          handler: descriptor[:handler],
          serializer: ->(payload, **) { payload },
          input_contract: descriptor[:input_contract],
          openapi: descriptor[:openapi]
        }
      end

      def recording_studio_api_available?
        defined?(RecordingStudioApi) &&
          RecordingStudioApi.respond_to?(:capability_action) &&
          RecordingStudioApi.respond_to?(:register_capability_action)
      end
    end
  end
end
