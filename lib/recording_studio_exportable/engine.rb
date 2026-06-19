# frozen_string_literal: true

module RecordingStudioExportable
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioExportable

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, RecordingStudioExportable.configuration.hooks.model_extensions_for(extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, RecordingStudioExportable.configuration.hooks.controller_extensions_for(extension_keys_for(target)))
      end

      private

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_exportable_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_exportable_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end
    end

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

    # Apply model extensions when models are loaded
    initializer "recording_studio_exportable.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioExportable::Engine.apply_model_extensions(model)
        end
      end
    end

    # Apply controller extensions
    initializer "recording_studio_exportable.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioExportable::Engine.apply_controller_extensions(controller)
        end
      end
    end
  end
end
