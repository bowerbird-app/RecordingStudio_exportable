# frozen_string_literal: true

module RecordingStudio
  module Exportable
    module Capabilities
      module Exportable
        CAPABILITY_NAME = :exportable

        def self.enabled(on:, exports:)
          type_name = RecordingStudio.recordable_type_name(on)
          raise ArgumentError, "recordable type is required" if type_name.blank?

          export_keys = Array(exports).map { |key| RecordingStudioExportable.configuration.normalize_key(key) }
          raise ArgumentError, "exports must include at least one export key" if export_keys.empty?

          export_keys.each { |key| RecordingStudioExportable.configuration.fetch_export_definition!(key) }

          RecordingStudio.enable_capability(CAPABILITY_NAME, on: type_name)
          RecordingStudio.set_capability_options(CAPABILITY_NAME, on: type_name, export_keys: export_keys)
          true
        end
      end
    end
  end
end
