# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioExportable::Configuration.new
  end

  def test_register_export_normalizes_key_and_applies_defaults
    definition = @configuration.export("Demo/Export-Key", columns: [:name]) { [] }

    assert_equal "demo.export_key", definition.key
    assert_equal 10_000, definition.max_rows
    assert_equal :view, definition.required_role
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

    RecordingStudioAccessible.stub(:authorized?, true) do
      assert_equal ["demo.visible"], @configuration.export_keys_for(
        recording: recording,
        actor: actor,
        context: :dashboard
      )
    end
  end

  def test_configure_without_block_is_safe
    RecordingStudioExportable.configure

    assert_kind_of RecordingStudioExportable::Configuration, RecordingStudioExportable.configuration
  end
end
