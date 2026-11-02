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

  def test_load_config_handles_errors_and_each_pair_fallback
    pair_config = Class.new do
      def each_pair
        yield(:max_rows, 15)
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

    assert_equal 15, RecordingStudioExportable.configuration.max_rows
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
        { max_rows: 33 }
      end
    end.new(app_config)

    # Should not raise even if xcfg.each_pair fails.
    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 33, RecordingStudioExportable.configuration.max_rows
  end

  def test_load_config_is_noop_without_config_sources
    app = Struct.new(:config).new(Object.new)

    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 50_000, RecordingStudioExportable.configuration.max_rows
    assert_equal :view, RecordingStudioExportable.configuration.default_required_role
  end

  def test_load_config_ignores_non_enumerable_yaml_and_merge_errors
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

    RecordingStudio.stub(:register_capability, true) do
      find_initializer("recording_studio_exportable.load_config").block.call(app)
    end

    assert_equal 22, RecordingStudioExportable.configuration.max_rows
  end

  private

  def find_initializer(name)
    RecordingStudioExportable::Engine.initializers.find { |initializer| initializer.name == name }
  end
end
