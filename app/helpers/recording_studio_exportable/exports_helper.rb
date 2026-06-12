# frozen_string_literal: true

module RecordingStudioExportable
  module ExportsHelper
    def recording_studio_export_button(export_key:, recording:, label: "Export CSV", params: {}, button_options: {})
      safe_join(
        [
          tag.form(action: recording_studio_exportable_exports_path, method: :post) do
            safe_join(
              [
                hidden_field_tag(:authenticity_token, form_authenticity_token),
                hidden_field_tag(:export_key, export_key),
                hidden_field_tag(:recording_id, recording.id),
                hidden_export_fields(params),
                render(FlatPack::Button::Component.new(text: label, type: "submit", **button_options))
              ].compact
            )
          end
        ]
      )
    end

    private

    def hidden_export_fields(params)
      params.to_h.map do |key, value|
        hidden_field_tag(key, value)
      end
    end

    def recording_studio_exportable_exports_path
      return recording_studio_exportable.exports_path if respond_to?(:recording_studio_exportable)

      RecordingStudioExportable::Engine.routes.url_helpers.exports_path
    end
  end
end
