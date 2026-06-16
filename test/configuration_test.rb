# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioExportable::Configuration.new
  end

  def test_register_export_normalizes_key_and_applies_defaults
    definition = @configuration.export("Demo/Export-Key", columns: [:name]) { [] }

    assert_equal "demo.export_key", definition.key
    assert_equal 50_000, definition.max_rows
    assert_equal :view, definition.required_role
  end

  def test_default_context_export_keys_resolver_supports_export_key_and_export_keys
    recording_with_many = Struct.new(:recordable).new(Struct.new(:export_keys).new(["demo.people"]))
    recording_with_one = Struct.new(:recordable).new(Struct.new(:export_key).new("demo.single"))

    assert_equal ["demo.people"], @configuration.context_export_keys_for(recording_with_many)
    assert_equal ["demo.single"], @configuration.context_export_keys_for(recording_with_one)
  end

  def test_idempotent_registration_returns_existing_equivalent_definition
    block = proc { [] }
    first = @configuration.export("demo.people", columns: [:name], &block)
    second = @configuration.export("demo.people", columns: [:name], &block)

    assert_same first, second
  end

  def test_duplicate_registration_requires_replace
    @configuration.export("demo.people", columns: [:name]) { [] }

    definition = @configuration.export("demo.people", columns: [:email]) { [] }
    assert_equal ["Email"], definition.headers
  end

  def test_replace_export_updates_definition
    @configuration.export("demo.people", columns: [:name]) { [] }
    definition = @configuration.replace_export("demo.people", columns: [:email]) { [] }

    assert_equal ["Email"], definition.headers
    assert_same definition, @configuration.export_definition("demo.people")
  end

  def test_merge_updates_known_defaults_and_ignores_unknown_keys
    @configuration.merge!("max_rows" => 25, "include_bom" => true, unknown: true)

    assert_equal 25, @configuration.max_rows
    assert @configuration.include_bom
    refute_respond_to @configuration, :unknown
  end

  def test_fetch_unknown_definition_raises_clear_error
    assert_raises(RecordingStudioExportable::UnknownExportDefinition) do
      @configuration.fetch_export_definition!("missing")
    end
  end

  def test_export_keys_for_respects_context_and_authorization
    recording = Object.new
    actor = Object.new

    @configuration.context_export_keys_resolver = ->(_recording) { ["demo.visible", "demo.hidden"] }
    @configuration.export("demo.visible", columns: [:name], screen_keys: [:dashboard]) { [] }
    @configuration.export("demo.hidden", columns: [:name], screen_keys: [:other]) { [] }

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.visible", "demo.hidden"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        assert_equal ["demo.visible"], @configuration.export_keys_for(
          recording: recording,
          actor: actor,
          context: :dashboard
        )
      end
    end
  end

  def test_export_keys_for_uses_capability_required_role
    recording = Struct.new(:recordable_type).new("DemoDashboard")
    actor = Object.new
    roles = []

    @configuration.context_export_keys_resolver = ->(_recording) { ["demo.admin"] }
    @configuration.export("demo.admin", columns: [:name]) { [] }

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.admin"], required_role: :admin }) do
      RecordingStudioAccessible.stub(:authorized?, ->(**kwargs) {
        roles << kwargs.fetch(:role)
        true
      }) do
        assert_equal ["demo.admin"], @configuration.export_keys_for(recording: recording, actor: actor)
      end
    end

    assert_equal [:admin], roles
  end

  def test_export_enabled_for_recording_requires_capability_export_keys
    recordable = Struct.new(:export_keys).new(["demo.people"])
    recording = Struct.new(:recordable_type, :recordable).new("DemoDashboard", recordable)

    RecordingStudio.stub(:capability_options, { required_role: :view }) do
      refute @configuration.export_enabled_for_recording?("demo.people", recording)
    end
  end

  def test_default_filter_log_sanitizer_redacts_sensitive_values
    filtered = @configuration.filter_log_sanitizer.call(
      "password" => "secret",
      "token" => "abc",
      "status" => "active"
    )

    assert_equal "[FILTERED]", filtered["password"]
    assert_equal "[FILTERED]", filtered["token"]
    assert_equal "active", filtered["status"]
  end

  def test_configure_without_block_is_safe
    RecordingStudioExportable.configure

    assert_kind_of RecordingStudioExportable::Configuration, RecordingStudioExportable.configuration
  end
end
