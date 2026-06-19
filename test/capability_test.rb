# frozen_string_literal: true

require "test_helper"

class CapabilityTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioExportable.instance_variable_get(:@configuration)
    RecordingStudioExportable.instance_variable_set(:@configuration, RecordingStudioExportable::Configuration.new)
    RecordingStudioExportable.configuration.export("demo.people", columns: [:name]) { [] }
    RecordingStudioExportable.configuration.export(
      "demo.articles",
      label: "Articles export",
      description: "Exports article records",
      required_role: :admin,
      columns: [:title],
      allowed_attributes: {
        articles: [{ key: :title, label: "Title", value: :title }]
      }
    ) { [] }
  end

  def teardown
    RecordingStudioExportable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_enabled_registers_recording_studio_capability_options
    enabled_calls = []
    option_calls = []

    RecordingStudio.stub(:enable_capability, ->(capability, on:) { enabled_calls << [capability, on] }) do
      RecordingStudio.stub(:set_capability_options, lambda { |capability, on:, **options|
        option_calls << [capability, on, options]
      }) do
        assert RecordingStudio::Exportable::Capabilities::Exportable.enabled(
          "Workspace",
          export_keys: ["demo/people"],
          required_role: :view,
          max_rows: 25,
          formats: [:csv]
        )
      end
    end

    assert_equal [[:exportable, "Workspace"]], enabled_calls
    assert_equal [[:exportable, "Workspace", { export_keys: ["demo.people"], required_role: :view, max_rows: 25, formats: [:csv] }]],
                 option_calls
  end

  def test_enabled_validates_only_exportable_options
    assert_raises(ArgumentError) do
      RecordingStudio::Exportable::Capabilities::Exportable.enabled("Workspace", max_rows: "many")
    end
  end

  def test_enabled_infers_recordable_from_class_context
    enabled_calls = []
    option_calls = []
    const_name = :CapabilityInferenceRecordable

    Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)

    RecordingStudio.stub(:enable_capability, ->(capability, on:) { enabled_calls << [capability, on] }) do
      RecordingStudio.stub(:set_capability_options, lambda { |capability, on:, **options|
        option_calls << [capability, on, options]
      }) do
        Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
          class CapabilityInferenceRecordable
            RecordingStudio::Exportable::Capabilities::Exportable.enabled(
              export_keys: ["demo/people"],
              required_role: :view
            )
          end
        RUBY
      end
    end

    assert_equal [[:exportable, "CapabilityInferenceRecordable"]], enabled_calls
    assert_equal [[:exportable, "CapabilityInferenceRecordable", { export_keys: ["demo.people"], required_role: :view }]],
                 option_calls
  ensure
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)
  end

  def test_enabled_installs_instance_export_key_helpers
    const_name = :CapabilityInstanceHelpersRecordable

    Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)

    RecordingStudio.stub(:enable_capability, true) do
      RecordingStudio.stub(:set_capability_options, true) do
        RecordingStudio.stub(:capability_options, { export_keys: ["demo/people", "demo/summary"] }) do
          Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
            class CapabilityInstanceHelpersRecordable
              RecordingStudio::Exportable::Capabilities::Exportable.enabled(
                export_keys: ["demo/people", "demo/summary"]
              )
            end
          RUBY

          instance = CapabilityInstanceHelpersRecordable.new
          assert_equal ["demo.people", "demo.summary"], instance.export_keys
          assert_nil instance.export_key
        end
      end
    end
  ensure
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)
  end

  def test_enabled_does_not_override_existing_export_keys_methods
    const_name = :CapabilityCustomExportKeysRecordable

    Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)

    RecordingStudio.stub(:enable_capability, true) do
      RecordingStudio.stub(:set_capability_options, true) do
        RecordingStudio.stub(:capability_options, { export_keys: ["demo/people"] }) do
          Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
            class CapabilityCustomExportKeysRecordable
              def export_keys
                ["custom.key"]
              end

              def export_key
                "custom.key"
              end

              RecordingStudio::Exportable::Capabilities::Exportable.enabled(
                export_keys: ["demo/people"]
              )
            end
          RUBY

          instance = CapabilityCustomExportKeysRecordable.new
          assert_equal ["custom.key"], instance.export_keys
          assert_equal "custom.key", instance.export_key
        end
      end
    end
  ensure
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)
  end

  def test_export_key_with_argument_returns_definition_metadata_for_enabled_key
    const_name = :CapabilityExportKeyDefinitionRecordable

    Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)

    RecordingStudio.stub(:enable_capability, true) do
      RecordingStudio.stub(:set_capability_options, true) do
        RecordingStudio.stub(:capability_options, { export_keys: ["demo/articles"] }) do
          Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
            class CapabilityExportKeyDefinitionRecordable
              RecordingStudio::Exportable::Capabilities::Exportable.enabled(
                export_keys: ["demo/articles"]
              )
            end
          RUBY

          instance = CapabilityExportKeyDefinitionRecordable.new
          definition = instance.export_key("demo/articles")

          refute_nil definition
          assert_equal "demo.articles", definition.key
          assert_equal "Articles export", definition.label
          assert_equal "Exports article records", definition.description
          assert_equal :admin, definition.required_role
          assert_equal ["articles"], definition.allowed_attribute_scopes
          assert_nil instance.export_key("demo.people")
        end
      end
    end
  ensure
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)
  end
end
