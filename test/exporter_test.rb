# frozen_string_literal: true

require "test_helper"

class ExporterTest < Minitest::Test
  FakeContext = Struct.new(:recordable_type, :recordable)
  FakeRecordable = Struct.new(:name)

  def setup
    @original_configuration = RecordingStudioExportable.instance_variable_get(:@configuration)
    RecordingStudioExportable.instance_variable_set(:@configuration, RecordingStudioExportable::Configuration.new)
    RecordingStudioExportable.configuration.context_export_keys_resolver = ->(_context) { ["demo.people"] }
    RecordingStudioExportable.configuration.register_export(
      "demo.people",
      context_types: ["DemoDashboard"],
      columns: [
        { key: :name, label: "=Name", value: :name },
        { key: :enabled, label: "Enabled", value: :enabled },
        { key: :formula, label: "Formula", value: :formula }
      ],
      filename: "People Export"
    ) do |context_recording:, filters:, **|
      assert_equal "DemoDashboard", context_recording.recordable_type
      assert_equal({ "nested" => { "status" => "ok" } }, filters)
      [
        { name: "Ada", enabled: false, formula: "=1+1" },
        { name: "+Grace", enabled: true, formula: "safe" }
      ]
    end
  end

  def teardown
    RecordingStudioExportable.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_export_generates_safe_csv_preserves_false_values_and_forwards_context
    context = FakeContext.new("DemoDashboard", FakeRecordable.new("Dash"))

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        result = RecordingStudioExportable.export(
          context_recording: context,
          actor: Object.new,
          export_key: nil,
          attributes: { columns: ["name", "enabled", "formula"] },
          filters: { "nested" => { "status" => "ok" } }
        )

        assert_equal "'=Name,Enabled,Formula\nAda,false,'=1+1\n'+Grace,true,safe\n", result.data
        assert_equal "People-Export.csv", result.filename
        assert_equal 2, result.row_count
      end
    end
  end

  def test_export_fails_closed_when_row_limit_is_exceeded
    RecordingStudioExportable.configuration.max_rows = 1

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        assert_raises(RecordingStudioExportable::ExportTooLarge) do
          RecordingStudioExportable.export(
            context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
            actor: Object.new
          )
        end
      end
    end
  end

  def test_export_requires_authenticated_actor
    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"] }) do
      RecordingStudioAccessible.stub(:authorized?, false) do
        assert_raises(RecordingStudioExportable::NotAuthorized) do
          RecordingStudioExportable.export(
            context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
            actor: nil
          )
        end
      end
    end
  end

  def test_csv_formula_guard_handles_line_feed_prefix
    RecordingStudioExportable.configuration.register_export(
      "demo.linefeed",
      context_types: ["DemoDashboard"],
      columns: { payload: { label: "Payload", value: :payload } },
      replace: true
    ) { [{ payload: "\n=1+1" }] }
    RecordingStudioExportable.configuration.context_export_keys_resolver = ->(_context) { ["demo.linefeed"] }

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.linefeed"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        result = RecordingStudioExportable.export(
          context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
          actor: Object.new
        )

        assert_includes result.data, "\"'\n=1+1\""
      end
    end
  end

  def test_unexpected_errors_are_not_wrapped_as_domain_errors
    RecordingStudioExportable.configuration.register_export(
      "demo.broken",
      context_types: ["DemoDashboard"],
      columns: { name: { label: "Name", value: :name } },
      replace: true
    ) { raise RuntimeError, "internal secret token" }
    RecordingStudioExportable.configuration.context_export_keys_resolver = ->(_context) { ["demo.broken"] }

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.broken"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        error = assert_raises(RuntimeError) do
          RecordingStudioExportable.export(
            context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
            actor: Object.new
          )
        end

        assert_equal "internal secret token", error.message
      end
    end
  end

  def test_export_log_is_created_after_authorization
    source = File.read(File.expand_path("../lib/recording_studio_exportable/exporter.rb", __dir__))

    assert_operator source.index("validate_authorization!(definition)"), :<, source.index("create_export_log(definition)")
  end

  def test_capability_options_can_tighten_authorization_and_row_limits
    calls = []

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"], required_role: :admin, max_rows: 1 }) do
      RecordingStudioAccessible.stub(:authorized?, ->(**kwargs) {
        calls << kwargs
        true
      }) do
        assert_raises(RecordingStudioExportable::ExportTooLarge) do
          RecordingStudioExportable.export(
            context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
            actor: Object.new
          )
        end
      end
    end

    assert_equal :admin, calls.first.fetch(:role)
  end

  def test_omitted_export_key_requires_exactly_one_allowed_key
    RecordingStudioExportable.configuration.context_export_keys_resolver = ->(_context) { ["demo.people", "demo.other"] }

    assert_raises(RecordingStudioExportable::UnknownExportKey) do
      RecordingStudioExportable.export(
        context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
        actor: Object.new
      )
    end
  end
end
