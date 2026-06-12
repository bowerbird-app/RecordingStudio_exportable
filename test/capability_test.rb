# frozen_string_literal: true

require "test_helper"

class CapabilityTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioExportable.instance_variable_get(:@configuration)
    RecordingStudioExportable.instance_variable_set(:@configuration, RecordingStudioExportable::Configuration.new)
    RecordingStudioExportable.configuration.export("demo.people", headers: ["Name"]) { [] }
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
            exports: ["demo/people"]
          )
        end
      end
    end

    assert_equal [[:exportable, "Workspace"]], enabled_calls
    assert_equal [[:exportable, "Workspace", { export_keys: ["demo.people"] }]], option_calls
  end

  def test_enabled_rejects_unknown_export_key
    RecordingStudio.stub(:recordable_type_name, "Workspace") do
      assert_raises(RecordingStudioExportable::UnknownExportDefinition) do
        RecordingStudio::Exportable::Capabilities::Exportable.enabled(on: "Workspace", exports: ["missing"])
      end
    end
  end
end
