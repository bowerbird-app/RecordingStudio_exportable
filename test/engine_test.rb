# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  def setup
    save_exportable_configuration!
  end

  def teardown
    restore_exportable_configuration!
  end

  def test_load_config_merges_config_sources_and_registers_exportable_capability
    xcfg = Struct.new(:recording_studio_exportable).new({ default_required_role: "edit" })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { max_rows: 12 }
      end
    end.new(app_config)

    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 12, RecordingStudioExportable.configuration.max_rows
    assert_equal "edit", RecordingStudioExportable.configuration.default_required_role
  end

  def test_load_config_skips_a_missing_yaml_file
    pair_config = Class.new do
      def each_pair
        yield(:max_rows, 15)
      end
    end.new

    xcfg = Struct.new(:recording_studio_exportable).new(pair_config)
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config, :paths).new(app_config, { "config" => Struct.new(:existent).new([]) })

    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 15, RecordingStudioExportable.configuration.max_rows
  end

  def test_load_config_raises_when_ordered_options_cannot_be_read
    bad_pair_config = Class.new do
      def each_pair
        raise "bad pair"
      end
    end.new

    xcfg = Struct.new(:recording_studio_exportable).new(bad_pair_config)
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      def config_for(_name)
        { max_rows: 33 }
      end
    end.new(app_config)

    assert_raises(RuntimeError) do
      RecordingStudio.stub(:register_capability, true) do
        find_initializer("recording_studio_exportable.load_config").block.call(app)
      end
    end
  end

  def test_load_config_raises_on_corrupt_yaml
    app = Struct.new(:config) do
      def config_for(_name)
        YAML.unsafe_load("a: [\n")
      end
    end.new(Object.new)

    assert_raises(Psych::SyntaxError) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end
  end

  def test_load_config_raises_when_yaml_uses_a_removed_key
    app = Struct.new(:config) do
      def config_for(_name)
        { "default_row_limit" => 12 }
      end
    end.new(Object.new)

    error = assert_raises(ArgumentError) do
      RecordingStudio.stub(:register_capability, true) do
        find_initializer("recording_studio_exportable.load_config").block.call(app)
      end
    end

    assert_match(/max_rows/, error.message)
    assert_equal 50_000, RecordingStudioExportable.configuration.max_rows
  end

  def test_load_config_is_noop_without_config_sources
    app = Struct.new(:config).new(Object.new)

    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 50_000, RecordingStudioExportable.configuration.max_rows
    assert_equal :view, RecordingStudioExportable.configuration.default_required_role
  end

  def test_load_config_raises_when_yaml_cannot_be_merged
    yaml = Class.new do
      def each
        raise "bad yaml"
      end
    end.new

    xcfg = Struct.new(:recording_studio_exportable).new({ max_rows: 22 })
    app_config = Struct.new(:x).new(xcfg)
    app = Struct.new(:config) do
      attr_accessor :yaml

      def config_for(_name)
        @yaml
      end
    end.new(app_config)
    app.yaml = yaml

    assert_raises(RuntimeError) do
      RecordingStudio.stub(:register_capability, true) do
        find_initializer("recording_studio_exportable.load_config").block.call(app)
      end
    end
  end

  def test_boot_does_not_warn_when_recording_studio_cache_is_absent
    assert_nil defined?(RecordingStudioCache)
    messages = []
    logger = Struct.new(:messages) do
      def warn(message)
        messages << message
      end
    end.new(messages)

    Rails.stub(:logger, logger) do
      find_initializer("recording_studio_exportable.warn_export_rate_store").block.call
    end

    assert_empty messages
  end

  def test_boot_warns_when_the_rate_limit_store_is_null_or_per_process
    null_messages = capture_rate_store_warning(ActiveSupport::Cache::NullStore.new)
    memory_messages = capture_rate_store_warning(ActiveSupport::Cache::MemoryStore.new)
    shared_messages = capture_rate_store_warning(Object.new)

    assert_match(/null store/, null_messages)
    assert_match(/per process/, memory_messages)
    assert_equal "", shared_messages
  end

  private

  def capture_rate_store_warning(store)
    messages = []
    logger = Struct.new(:messages) do
      def warn(message)
        messages << message
      end
    end.new(messages)
    RecordingStudioExportable.stub(:export_rate_cache_store, store) do
      Rails.stub(:logger, logger) do
        RecordingStudioExportable.send(:warn_unless_shared_rate_limit_store)
      end
    end
    messages.join
  end

  def find_initializer(name)
    RecordingStudioExportable::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
