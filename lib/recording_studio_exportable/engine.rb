# frozen_string_literal: true

module RecordingStudioExportable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioExportable

    initializer "recording_studio_exportable.load_config" do |app|
      yaml = RecordingStudioExportable::Engine.host_yaml(app)
      RecordingStudioExportable.configuration.merge!(yaml) if yaml.respond_to?(:each)

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_exportable)
        xcfg = app.config.x.recording_studio_exportable
        if xcfg.respond_to?(:to_h)
          RecordingStudioExportable.configuration.merge!(xcfg.to_h)
        elsif xcfg.respond_to?(:each_pair)
          hash = {}
          xcfg.each_pair { |key, value| hash[key] = value }
          RecordingStudioExportable.configuration.merge!(hash) if hash.any?
        end
      end

      RecordingStudio.register_capability(:exportable, source: "RecordingStudioExportable")
    end

    initializer "recording_studio_exportable.warn_export_rate_store" do
      next unless defined?(RecordingStudioCache)

      RecordingStudioExportable.warn_unless_shared_rate_limit_store
    end

    initializer "recording_studio_exportable.register_recording_studio_api_actions",
                before: "recording_studio_api.after_initialize" do
      RecordingStudioExportable::Api.register_capability_action!
    end

    def self.host_yaml(app)
      return unless app.respond_to?(:config_for)
      return app.config_for(:recording_studio_exportable) unless app.respond_to?(:paths)

      config_root = app.paths["config"].existent.first
      return if config_root.nil?
      return unless File.exist?(File.join(config_root, "recording_studio_exportable.yml"))

      app.config_for(:recording_studio_exportable)
    end
  end
end
