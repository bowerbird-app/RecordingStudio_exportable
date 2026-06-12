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

    RecordingStudio.stub(:recordable_type_name, "Workspace") do
      RecordingStudio.stub(:enable_capability, ->(capability, on:) { enabled_calls << [capability, on] }) do
        RecordingStudio.stub(:set_capability_options, ->(capability, on:, **options) {
          option_calls << [capability, on, options]
        }) do
          assert RecordingStudio::Exportable::Capabilities::Exportable.enabled(
            on: "Workspace",
            export_keys: ["demo/people"],
            required_role: :view,
            max_rows: 25,
            formats: [:csv]
          )
        end
      end
    end

    assert_equal [[:exportable, "Workspace"]], enabled_calls
    assert_equal [[:exportable, "Workspace", { export_keys: ["demo.people"], required_role: :view, max_rows: 25, formats: [:csv] }]], option_calls
  end

  def test_enabled_validates_only_exportable_options
    RecordingStudio.stub(:recordable_type_name, "Workspace") do
      assert_raises(ArgumentError) do
        RecordingStudio::Exportable::Capabilities::Exportable.enabled(on: "Workspace", max_rows: "many")
      end
    end
  end
end
