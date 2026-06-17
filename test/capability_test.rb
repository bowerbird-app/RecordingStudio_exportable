# frozen_string_literal: true

require "test_helper"

class CapabilityTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioExportable.instance_variable_get(:@configuration)
    RecordingStudioExportable.instance_variable_set(:@configuration, RecordingStudioExportable::Configuration.new)
    RecordingStudioExportable.configuration.export("demo.people", columns: [:name]) { [] }
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
end
