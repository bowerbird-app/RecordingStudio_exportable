# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioExportable::Configuration.new
  end

  def test_register_export_normalizes_key_and_applies_defaults
    definition = @configuration.register_export("Demo/Export-Key", columns: [:name]) { [] }

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
    first = @configuration.register_export("demo.people", columns: [:name], &block)
    second = @configuration.register_export("demo.people", columns: [:name], &block)

    assert_same first, second
  end

  def test_duplicate_registration_requires_replace
    @configuration.register_export("demo.people", columns: [:name]) { [] }

    definition = @configuration.register_export("demo.people", columns: [:email]) { [] }
    assert_equal ["Email"], definition.headers
  end

  def test_replace_export_updates_definition
    @configuration.register_export("demo.people", columns: [:name]) { [] }
    definition = @configuration.replace_export("demo.people", columns: [:email]) { [] }

    assert_equal ["Email"], definition.headers
    assert_same definition, @configuration.export_definition_for("demo.people")
  end

  def test_removed_configuration_aliases_are_gone
    refute_respond_to @configuration, :default_row_limit
    refute_respond_to @configuration, :default_row_limit=
    refute_respond_to @configuration, :export
    refute_respond_to @configuration, :export_definition

    @configuration.max_rows = 10

    {
      "default_row_limit" => "max_rows",
      "export" => "register_export",
      "export_definition" => "export_definition_for"
    }.each do |removed_key, replacement|
      error = assert_raises(ArgumentError) do
        @configuration.merge!(removed_key => 12)
      end

      assert_match(/#{Regexp.escape(replacement)}/, error.message)
    end

    assert_equal 10, @configuration.max_rows
  end

  def test_merge_updates_known_defaults_and_ignores_unknown_keys
    @configuration.merge!("max_rows" => 25, "include_bom" => true, unknown: true)

    assert_equal 25, @configuration.max_rows
    assert @configuration.include_bom
    refute_respond_to @configuration, :unknown
  end

  def test_layout_can_be_configured
    @configuration.merge!("layout" => "flat_pack_sidebar")

    assert_equal "flat_pack_sidebar", @configuration.layout
  end

  def test_fetch_unknown_definition_raises_clear_error
    assert_raises(RecordingStudioExportable::UnknownExportKey) do
      @configuration.fetch_export_definition!("missing")
    end
  end

  def test_export_keys_for_respects_context_and_authorization
    recording = Object.new
    actor = Object.new

    @configuration.context_export_keys_resolver = ->(_recording) { ["demo.visible", "demo.hidden"] }
    @configuration.register_export("demo.visible", columns: [:name], screen_keys: [:dashboard]) { [] }
    @configuration.register_export("demo.hidden", columns: [:name], screen_keys: [:other]) { [] }

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
    @configuration.register_export("demo.admin", columns: [:name]) { [] }

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.admin"], required_role: :admin }) do
      RecordingStudioAccessible.stub(:authorized?, lambda { |**kwargs|
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

  def test_default_actor_resolver_reads_current_actor_and_ignores_the_controller
    actor = Object.new
    controller = Object.new
    controller.define_singleton_method(:current_user) do
      raise "controller.current_user is not the default actor"
    end

    with_current_actor(actor) do
      resolved = RecordingStudioExportable::Configuration.new.resolve_actor(controller)

      assert_same actor, resolved
    end
  end

  private

  def with_current_actor(actor)
    unless Object.const_defined?(:Current)
      Object.const_set(:Current, Module.new)
    end
    unless Current.respond_to?(:actor)
      Current.define_singleton_method(:actor) { nil }
    end

    Current.stub(:actor, actor) { yield }
  end
end
