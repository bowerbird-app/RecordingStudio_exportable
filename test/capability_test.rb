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

    @original_capabilities =
      RecordingStudio.configuration.instance_variable_get(:@capabilities)&.transform_values(&:dup) || {}
    @original_capability_options =
      RecordingStudio.configuration.instance_variable_get(:@capability_options)&.dup || {}
    @defined_recordables = []
  end

  def teardown
    Array(@defined_recordables).each do |const_name|
      Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)
    end
    RecordingStudioExportable.instance_variable_set(:@configuration, @original_configuration)
    RecordingStudio.configuration.instance_variable_set(:@capabilities, @original_capabilities)
    RecordingStudio.configuration.instance_variable_set(:@capability_options, @original_capability_options)
  end

  def test_to_is_a_thin_wrapper_around_include_for
    captured_name = nil
    captured_options = nil

    RecordingStudio::Capabilities.stub(:include_for, lambda { |name, **options, &block|
      captured_name = name
      captured_options = options
      block&.call(Class.new)
      Module.new
    }) do
      RecordingStudio::Capabilities::Exportable.to(
        export_keys: ["demo/people"],
        required_role: :view,
        max_rows: 25,
        formats: [:csv]
      )
    end

    assert_equal :exportable, captured_name
    assert_equal(
      { export_keys: ["demo.people"], required_role: :view, max_rows: 25, formats: [:csv] },
      captured_options
    )
  end

  def test_to_enables_exportable_and_sets_options
    host = define_recordable(:ToEnablementRecordable)

    host.include RecordingStudio::Capabilities::Exportable.to(
      export_keys: ["demo/people"],
      required_role: :view,
      max_rows: 25,
      formats: [:csv]
    )

    assert RecordingStudio.capability_enabled?(:exportable, for: host)
    assert_equal(
      { export_keys: ["demo.people"], required_role: :view, max_rows: 25, formats: [:csv] },
      RecordingStudio.capability_options(:exportable, for: host)
    )
  end

  def test_to_accepts_exports_alias
    host = define_recordable(:ToExportsAliasRecordable)

    host.include RecordingStudio::Capabilities::Exportable.to(exports: ["demo/people"])

    assert RecordingStudio.capability_enabled?(:exportable, for: host)
    assert_equal({ export_keys: ["demo.people"] }, RecordingStudio.capability_options(:exportable, for: host))
  end

  def test_to_validates_exportable_options
    error = assert_raises(ArgumentError) do
      RecordingStudio::Capabilities::Exportable.to(max_rows: "many")
    end

    assert_match(/max_rows must be an integer/, error.message)
  end

  def test_to_rejects_unknown_options
    error = assert_raises(ArgumentError) do
      RecordingStudio::Capabilities::Exportable.to(not_a_real_option: true)
    end

    assert_match(/unknown exportable option/, error.message)
  end

  def test_to_does_not_register_the_capability
    host = define_recordable(:ToDoesNotRegisterRecordable)
    registered_before = RecordingStudio.registered_capabilities.dup

    host.include RecordingStudio::Capabilities::Exportable.to(export_keys: ["demo/people"])

    assert_equal registered_before.keys.sort, RecordingStudio.registered_capabilities.keys.sort
  end

  def test_installing_the_mixin_without_to_does_not_enable_exportable
    host = define_recordable(:InstallDoesNotEnableRecordable)

    refute RecordingStudio.capability_enabled?(:exportable, for: host)
    refute_includes RecordingStudio.capabilities_for(host), :exportable
  end

  def test_enabled_still_enables_through_to_and_is_deprecated
    host = define_recordable(:DeprecatedEnabledRecordable)
    stderr = capture_io do
      Object.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        class DeprecatedEnabledRecordable
          RecordingStudio::Capabilities::Exportable.enabled(
            export_keys: ["demo/people"],
            required_role: :view
          )
        end
      RUBY
    end.last

    assert_match(/DEPRECATION/, stderr)
    assert_match(/Exportable.enabled is deprecated/, stderr)
    assert_match(/Exportable\.to/, stderr)
    assert RecordingStudio.capability_enabled?(:exportable, for: host)
    assert_equal(
      { export_keys: ["demo.people"], required_role: :view },
      RecordingStudio.capability_options(:exportable, for: host)
    )
  end

  def test_enabled_accepts_an_explicit_recordable
    host = define_recordable(:ExplicitEnabledRecordable)
    stderr = capture_io do
      RecordingStudio::Capabilities::Exportable.enabled(
        host,
        export_keys: ["demo/people"]
      )
    end.last

    assert_match(/DEPRECATION/, stderr)
    assert RecordingStudio.capability_enabled?(:exportable, for: host)
  end

  def test_enabled_accepts_a_recordable_type_name
    host = define_recordable(:NamedEnabledRecordable)
    stderr = capture_io do
      RecordingStudio::Capabilities::Exportable.enabled(
        "NamedEnabledRecordable",
        export_keys: ["demo/people"]
      )
    end.last

    assert_match(/DEPRECATION/, stderr)
    assert RecordingStudio.capability_enabled?(:exportable, for: host)
  end

  def test_enabled_requires_a_resolvable_recordable
    stderr = capture_io do
      error = assert_raises(ArgumentError) do
        RecordingStudio::Capabilities::Exportable.enabled(export_keys: ["demo/people"])
      end

      assert_match(/recordable is required/, error.message)
    end.last

    assert_match(/DEPRECATION/, stderr)
  end

  def test_to_rejects_blank_required_role
    error = assert_raises(ArgumentError) do
      RecordingStudio::Capabilities::Exportable.to(required_role: "")
    end

    assert_match(/required_role cannot be blank/, error.message)
  end

  def test_to_rejects_blank_formats
    error = assert_raises(ArgumentError) do
      RecordingStudio::Capabilities::Exportable.to(formats: [""])
    end

    assert_match(/formats cannot be blank/, error.message)
  end

  def test_legacy_constant_path_aliases_capabilities_exportable
    assert_same RecordingStudio::Capabilities::Exportable,
                RecordingStudio::Exportable::Capabilities::Exportable
  end

  def test_to_installs_instance_export_key_helpers
    host = define_recordable(:ToInstanceHelpersRecordable)

    host.include RecordingStudio::Capabilities::Exportable.to(
      export_keys: ["demo/people", "demo/summary"]
    )

    instance = host.new
    RecordingStudio.stub(:capability_options, { export_keys: ["demo/people", "demo/summary"] }) do
      assert_equal ["demo.people", "demo.summary"], instance.export_keys
      assert_nil instance.export_key
    end
  end

  def test_to_does_not_override_existing_export_keys_methods
    host = define_recordable(:ToCustomExportKeysRecordable)
    host.class_eval do
      def export_keys
        ["custom.key"]
      end

      def export_key
        "custom.key"
      end
    end

    host.include RecordingStudio::Capabilities::Exportable.to(export_keys: ["demo/people"])

    instance = host.new
    assert_equal ["custom.key"], instance.export_keys
    assert_equal "custom.key", instance.export_key
  end

  def test_export_key_with_argument_returns_definition_metadata_for_enabled_key
    host = define_recordable(:ToExportKeyDefinitionRecordable)
    host.include RecordingStudio::Capabilities::Exportable.to(export_keys: ["demo/articles"])

    instance = host.new
    RecordingStudio.stub(:capability_options, { export_keys: ["demo/articles"] }) do
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

  def test_documented_host_verb_is_include_to
    readme = File.read(File.expand_path("../README.md", __dir__))
    dummy_dashboard = File.read(File.expand_path("dummy/app/models/demo_dashboard.rb", __dir__))

    assert_includes readme, "include RecordingStudio::Capabilities::Exportable.to"
    refute_match(/Capabilities::Exportable\.enabled\(/, readme)
    assert_includes dummy_dashboard, "include RecordingStudio::Capabilities::Exportable.to"
    refute_includes dummy_dashboard, ".enabled("
  end

  private

  def define_recordable(const_name)
    Object.send(:remove_const, const_name) if Object.const_defined?(const_name, false)
    @defined_recordables << const_name
    Object.const_set(const_name, Class.new)
  end
end
