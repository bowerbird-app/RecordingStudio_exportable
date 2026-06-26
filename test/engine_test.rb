# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    @original_configuration = RecordingStudioExportable.instance_variable_get(:@configuration)
    RecordingStudioExportable.instance_variable_set(:@configuration, RecordingStudioExportable::Configuration.new)
  end

  def teardown
    RecordingStudioExportable.configuration.hooks.clear!
    RecordingStudioExportable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_load_config_merges_config_sources_and_registers_exportable_capability
    xcfg = Struct.new(:recording_studio_exportable).new({ default_required_role: "edit" })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { default_row_limit: 12 }
      end
    end.new(app_config)

    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 12, RecordingStudioExportable.configuration.default_row_limit
    assert_equal "edit", RecordingStudioExportable.configuration.default_required_role
  end

  def test_load_config_handles_errors_and_each_pair_fallback
    pair_config = Class.new do
      def each_pair
        yield(:default_row_limit, 15)
      end
    end.new

    xcfg = Struct.new(:recording_studio_exportable).new(pair_config)
    app_config = Struct.new(:x).new(xcfg)

    app = Struct.new(:config) do
      def config_for(_name)
        raise "missing file"
      end
    end.new(app_config)

    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 15, RecordingStudioExportable.configuration.default_row_limit
  end

  def test_load_config_swallow_each_pair_errors
    bad_pair_config = Class.new do
      def each_pair
        raise "bad pair"
      end
    end.new

    xcfg = Struct.new(:recording_studio_exportable).new(bad_pair_config)
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { default_row_limit: 33 }
      end
    end.new(app_config)

    # Should not raise even if xcfg.each_pair fails.
    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 33, RecordingStudioExportable.configuration.default_row_limit
  end

  def test_load_config_is_noop_without_config_sources
    app = Struct.new(:config).new(Object.new)

    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 50_000, RecordingStudioExportable.configuration.default_row_limit
    assert_equal :view, RecordingStudioExportable.configuration.default_required_role
  end

  def test_load_config_ignores_non_enumerable_yaml_and_merge_errors
    yaml = Class.new do
      def each
        raise "bad yaml"
      end
    end.new

    xcfg = Struct.new(:recording_studio_exportable).new({ default_row_limit: 22 })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      attr_accessor :yaml

      def config_for(_name)
        @yaml
      end
    end.new(app_config)
    app.yaml = yaml

    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 22, RecordingStudioExportable.configuration.default_row_limit
  end

  def test_apply_extension_initializers_register_active_support_on_load_callbacks
    to_prepare_blocks = []
    config_stub = Object.new
    config_stub.define_singleton_method(:to_prepare) do |&block|
      to_prepare_blocks << block
    end

    RecordingStudioExportable::Engine.stub(:config, config_stub) do
      find_initializer("recording_studio_exportable.apply_model_extensions").block.call
      find_initializer("recording_studio_exportable.apply_controller_extensions").block.call
    end

    assert_equal 2, to_prepare_blocks.size
  end

  def test_model_extension_initializer_skips_abstract_models
    to_prepare_blocks = []
    config_stub = Object.new
    config_stub.define_singleton_method(:to_prepare) do |&block|
      to_prepare_blocks << block
    end

    abstract_model = Class.new do
      def self.abstract_class?
        true
      end
    end
    concrete_model = Class.new do
      def self.abstract_class?
        false
      end
    end
    applied = []
    active_record_base = Class.new
    active_record_base.define_singleton_method(:descendants) { [abstract_model, concrete_model] }

    RecordingStudioExportable::Engine.stub(:config, config_stub) do
      find_initializer("recording_studio_exportable.apply_model_extensions").block.call
    end

    with_temporary_nested_constant(:ActiveRecord, :Base, active_record_base) do
      RecordingStudioExportable::Engine.stub(:apply_model_extensions, ->(model) { applied << model }) do
        to_prepare_blocks.first.call
      end
    end

    assert_equal [concrete_model], applied
  end

  def test_controller_extension_initializer_applies_all_controllers
    to_prepare_blocks = []
    config_stub = Object.new
    config_stub.define_singleton_method(:to_prepare) do |&block|
      to_prepare_blocks << block
    end

    first_controller = Class.new
    second_controller = Class.new
    applied = []
    action_controller_base = Class.new
    action_controller_base.define_singleton_method(:descendants) { [first_controller, second_controller] }

    RecordingStudioExportable::Engine.stub(:config, config_stub) do
      find_initializer("recording_studio_exportable.apply_controller_extensions").block.call
    end

    with_temporary_nested_constant(:ActionController, :Base, action_controller_base) do
      RecordingStudioExportable::Engine.stub(:apply_controller_extensions, ->(controller) { applied << controller }) do
        to_prepare_blocks.first.call
      end
    end

    assert_equal [first_controller, second_controller], applied
  end

  def test_apply_model_extensions_adds_registered_methods_once
    model_class = Class.new do
      def self.name
        "ExampleRecord"
      end
    end

    RecordingStudioExportable.configuration.hooks.extend_model(:ExampleRecord) do
      def template_extension_method
        :applied
      end
    end

    RecordingStudioExportable::Engine.apply_model_extensions(model_class)
    RecordingStudioExportable::Engine.apply_model_extensions(model_class)

    instance = model_class.new
    assert_equal :applied, instance.template_extension_method
  end

  def test_apply_controller_extensions_matches_demodulized_name
    controller_class = Class.new do
      def self.name
        "Admin::DashboardController"
      end
    end

    RecordingStudioExportable.configuration.hooks.extend_controller(:DashboardController) do
      def template_controller_extension
        :applied
      end
    end

    RecordingStudioExportable::Engine.apply_controller_extensions(controller_class)

    instance = controller_class.new
    assert_equal :applied, instance.template_controller_extension
  end

  def test_apply_extensions_flattens_compacts_and_tracks_identity
    target = Class.new
    extension = proc do
      def generated_method
        :generated
      end
    end

    RecordingStudioExportable::Engine.send(:apply_extensions, target, [nil, [extension, extension]])

    assert_equal :generated, target.new.generated_method
    assert_equal true,
                 target.instance_variable_get(:@recording_studio_exportable_applied_extensions).compare_by_identity?
  end

  def test_apply_extensions_returns_without_target
    assert_nil RecordingStudioExportable::Engine.send(:apply_extensions, nil, [])
  end

  def test_extension_keys_for_includes_demodulized_name
    namespaced = Class.new do
      def self.name
        "Admin::ReportsController"
      end
    end

    expected_keys = [:"Admin::ReportsController"]
    expected_keys << :ReportsController

    assert_equal expected_keys, RecordingStudioExportable::Engine.send(:extension_keys_for, namespaced)
  end

  def test_extension_keys_for_removes_duplicate_names
    plain = Class.new do
      def self.name
        "ReportsController"
      end
    end

    assert_equal [:ReportsController], RecordingStudioExportable::Engine.send(:extension_keys_for, plain)
  end

  private

  def with_temporary_nested_constant(parent_name, child_name, value)
    parent_defined = Object.const_defined?(parent_name, false)
    parent = parent_defined ? Object.const_get(parent_name) : Object.const_set(parent_name, Module.new)
    child_defined = parent.const_defined?(child_name, false)
    previous_child = parent.const_get(child_name) if child_defined

    parent.const_set(child_name, value)
    yield
  ensure
    parent.send(:remove_const, child_name) if parent.const_defined?(child_name, false)
    parent.const_set(child_name, previous_child) if child_defined
    Object.send(:remove_const, parent_name) unless parent_defined
  end

  def find_initializer(name)
    RecordingStudioExportable::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
