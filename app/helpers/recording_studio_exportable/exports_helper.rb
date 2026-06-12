# frozen_string_literal: true

module RecordingStudioExportable
  module ExportsHelper
    def recording_studio_export_button(context_recording:, export_key: nil, attributes: nil, filters: {}, format: :csv,
                                       filename: nil, text: "Export CSV", icon: "arrow-down-tray", style: :secondary,
                                       size: :sm, icon_only: false, data: {}, aria: {}, **system_arguments)
      raise ArgumentError, "context_recording is required" unless context_recording.respond_to?(:id)
      raise ArgumentError, "FlatPack::Button::Component is required" unless defined?(FlatPack::Button::Component)

      tag.form(action: recording_studio_exportable_exports_path, method: :post, data: data, aria: aria) do
        safe_join(
          [
            hidden_field_tag(:authenticity_token, form_authenticity_token),
            hidden_field_tag(:context_recording_id, context_recording.id),
            hidden_field_tag(:export_key, export_key),
            hidden_field_tag(:format, format),
            hidden_field_tag(:filename, filename),
            hidden_nested_fields("attributes", attributes),
            hidden_nested_fields("filters", filters),
            render(FlatPack::Button::Component.new(
              text: text,
              icon: icon,
              type: "submit",
              style: style,
              size: size,
              icon_only: icon_only,
              **system_arguments
            ))
          ].compact
        )
      end
    end

    private

    def hidden_nested_fields(prefix, value)
      case value
      when nil
        nil
      when Hash
        safe_join(value.flat_map { |key, child| hidden_nested_fields("#{prefix}[#{key}]", child) })
      when Array
        safe_join(value.each_with_index.map { |child, index| hidden_nested_fields("#{prefix}[#{index}]", child) })
      else
        hidden_field_tag(prefix, value)
      end
    end

    def recording_studio_exportable_exports_path
      return recording_studio_exportable.exports_path if respond_to?(:recording_studio_exportable)

      RecordingStudioExportable::Engine.routes.url_helpers.exports_path
    end
  end
end
