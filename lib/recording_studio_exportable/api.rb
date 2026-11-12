# frozen_string_literal: true

require "recording_studio_exportable/api/export_recording"
require "recording_studio_exportable/api/list_export_keys"

module RecordingStudioExportable
  module Api
    ACTION_VERSION = "1.0.0"
    INTERNAL_ROUTE_PARAMETER_KEYS = %i[api_key api_version].push("api_key", "api_version").freeze

    class << self
      def register_capability_action!
        return unless recording_studio_api_available?

        if named_api_registration_supported?
          RecordingStudioApi.configuration.each_api do |api_definition|
            register_actions_for(api_definition.name)
          end
        else
          register_actions_for(nil)
        end
      end

      private

      def register_actions_for(api_name)
        action_descriptors.each do |descriptor|
          next if capability_action_registered?(descriptor[:name], api_name)

          options = capability_action_options(descriptor)
          if api_name
            RecordingStudioApi.register_capability_action(descriptor[:name], api: api_name, **options)
          else
            RecordingStudioApi.register_capability_action(descriptor[:name], **options)
          end
        end
      end

      def capability_action_registered?(name, api_name)
        if api_name
          RecordingStudioApi.capability_action(name, api: api_name)
        else
          RecordingStudioApi.capability_action(name)
        end
      end

      def named_api_registration_supported?
        RecordingStudioApi.respond_to?(:configuration) &&
          RecordingStudioApi.configuration.respond_to?(:each_api) &&
          action_api_accepts_api?(:capability_action) &&
          action_api_accepts_api?(:register_capability_action)
      end

      def action_api_accepts_api?(method_name)
        RecordingStudioApi.method(method_name).parameters.any? do |type, name|
          type == :keyrest || (name == :api && %i[key keyreq].include?(type))
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
            input_contract: export_input_contract,
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
            input_contract: export_keys_input_contract,
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

      def export_input_contract
        wrap_input_contract(
          reject_unknown: true,
          fields: {
            export_key: { type: :string, allow_blank: false },
            format: { type: :string, allow_blank: false },
            filename: { type: :string, allow_blank: false },
            attributes: { type: :object, allow_blank: true },
            filters: { type: :object, allow_blank: true }
          }
        )
      end

      def export_keys_input_contract
        wrap_input_contract(
          reject_unknown: true,
          fields: {
            screen_key: { type: :string, allow_blank: false }
          }
        )
      end

      def wrap_input_contract(definition)
        return definition unless defined?(RecordingStudioApi::ActionInputContract)

        route_parameter_filtering_contract.new(definition)
      end

      def route_parameter_filtering_contract
        Class.new(RecordingStudioApi::ActionInputContract) do
          define_method(:call) do |raw_params|
            params = raw_params.respond_to?(:to_h) ? raw_params.to_h : raw_params
            if params.respond_to?(:except)
              params = params.except(*RecordingStudioExportable::Api::INTERNAL_ROUTE_PARAMETER_KEYS)
            end
            super(params)
          end
        end
      end
    end
  end
end
