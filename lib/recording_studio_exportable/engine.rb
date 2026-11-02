# frozen_string_literal: true

module RecordingStudioExportable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioExportable

    initializer "recording_studio_exportable.load_config" do |app|
      # Load config/recording_studio_exportable.yml via Rails config_for if present
      if app.respond_to?(:config_for)
        begin
          yaml = begin
            app.config_for(:recording_studio_exportable)
          rescue StandardError
            nil
          end
          RecordingStudioExportable.configuration.merge!(yaml) if yaml.respond_to?(:each)
        rescue StandardError => _e
          # ignore load errors; host app can provide initializer overrides
        end
      end

      # Merge Rails.application.config.x.recording_studio_exportable if present
      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_exportable)
        xcfg = app.config.x.recording_studio_exportable
        if xcfg.respond_to?(:to_h)
          RecordingStudioExportable.configuration.merge!(xcfg.to_h)
        else
          begin
            # try converting OrderedOptions
            hash = {}
            xcfg.each_pair { |k, v| hash[k] = v } if xcfg.respond_to?(:each_pair)
            RecordingStudioExportable.configuration.merge!(hash) if hash&.any?
          rescue StandardError => _e
            # ignore
          end
        end
      end

      RecordingStudio.register_capability(:exportable, source: "RecordingStudioExportable")
    end
  end
end
