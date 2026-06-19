# frozen_string_literal: true

module RecordingStudioExportable
  module ExportsHelper
    UNAUTHORIZED_EXPORT_BUTTON_BEHAVIORS = %i[hide disable].freeze

    def recording_studio_export_button(context_recording:, export_key: nil, columns: nil, attributes: nil, filters: {}, format: :csv,
                                       filename: nil, text: "Export CSV", icon: "arrow-down-tray", style: :secondary,
                                       size: :sm, icon_only: false, data: {}, aria: {}, **system_arguments)
      raise ArgumentError, "context_recording is required" unless context_recording.respond_to?(:id)
      raise ArgumentError, "FlatPack::Button::Component is required" unless defined?(FlatPack::Button::Component)

      attributes = merge_export_columns(attributes, columns)

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

    def recording_studio_export_access_button(context_recording:, export_key: nil, columns: nil, attributes: nil, filters: {}, format: :csv,
                                              filename: nil, text: "Export CSV", icon: "arrow-down-tray", style: :secondary,
                                              size: :sm, icon_only: false, unauthorized_behavior: :hide,
                                              unauthorized_text: nil, data: {}, aria: {}, **system_arguments)
      behavior = unauthorized_behavior.to_sym
      unless UNAUTHORIZED_EXPORT_BUTTON_BEHAVIORS.include?(behavior)
        raise ArgumentError, "unauthorized_behavior must be one of: #{UNAUTHORIZED_EXPORT_BUTTON_BEHAVIORS.join(', ')}"
      end

      effective_export_key = resolved_export_key(context_recording: context_recording, export_key: export_key)
      return if effective_export_key.nil? && behavior == :hide

      authorized = export_authorized_for_actor?(context_recording: context_recording, export_key: effective_export_key)
      return if !authorized && behavior == :hide

      return recording_studio_export_button(
        context_recording: context_recording,
        export_key: effective_export_key,
        columns: columns,
        attributes: attributes,
        filters: filters,
        format: format,
        filename: filename,
        text: text,
        icon: icon,
        style: style,
        size: size,
        icon_only: icon_only,
        data: data,
        aria: aria,
        **system_arguments
      ) if authorized

      disabled_aria = { disabled: true }.merge(aria || {})

      render(FlatPack::Button::Component.new(
        text: unauthorized_text || text,
        icon: icon,
        type: "button",
        style: style,
        size: size,
        icon_only: icon_only,
        disabled: true,
        aria: disabled_aria,
        **system_arguments
      ))
    end

    private

    def export_authorized_for_actor?(context_recording:, export_key:)
      return false if export_key.blank?

      actor = current_export_actor
      return false if actor.blank?

      allowed_keys = RecordingStudioExportable.configuration.export_keys_for(
        recording: context_recording,
        actor: actor
      )
      allowed_keys.include?(RecordingStudioExportable.configuration.normalize_key(export_key))
    rescue StandardError
      false
    end

    def resolved_export_key(context_recording:, export_key:)
      return export_key if export_key.present?

      keys = RecordingStudioExportable.configuration.context_export_keys_for(context_recording)
      keys.one? ? keys.first : nil
    end

    def current_export_actor
      resolver = RecordingStudioExportable.configuration.current_actor
      actor = resolver.call(controller: (respond_to?(:controller) ? controller : nil)) if resolver.respond_to?(:call)
      return actor if actor.present?

      Current.actor if defined?(Current) && Current.respond_to?(:actor)
    rescue StandardError
      Current.actor if defined?(Current) && Current.respond_to?(:actor)
    end

    def hidden_nested_fields(prefix, value)
      case value
      when nil
        nil
      when Hash
        safe_join(value.flat_map { |key, child| hidden_nested_fields("#{prefix}[#{key}]", child) })
      when Array
        safe_join(value.map { |child| hidden_nested_fields("#{prefix}[]", child) })
      else
        hidden_field_tag(prefix, value)
      end
    end

    def merge_export_columns(attributes, columns)
      return attributes if columns.blank?

      attributes_hash = attributes.is_a?(Hash) ? attributes.dup : {}
      attributes_hash[:columns] = columns
      attributes_hash
    end

    def recording_studio_exportable_exports_path
      return recording_studio_exportable.exports_path if respond_to?(:recording_studio_exportable)

      RecordingStudioExportable::Engine.routes.url_helpers.exports_path
    end
  end
end
