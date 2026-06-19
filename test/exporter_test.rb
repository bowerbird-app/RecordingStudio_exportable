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

  def test_authorization_runs_before_column_validation
    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"] }) do
      RecordingStudioAccessible.stub(:authorized?, false) do
        assert_raises(RecordingStudioExportable::NotAuthorized) do
          RecordingStudioExportable.export(
            context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
            actor: Object.new,
            attributes: { columns: ["missing"] }
          )
        end
      end
    end
  end

  def test_export_requires_enabled_capability_even_when_recordable_exposes_keys
    recordable = Struct.new(:export_keys).new(["demo.people"])
    context = FakeContext.new("DemoDashboard", recordable)

    RecordingStudio.stub(:capability_options, {}) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        assert_raises(RecordingStudioExportable::ExportNotAllowedForContext) do
          RecordingStudioExportable.export(
            context_recording: context,
            actor: Object.new,
            export_key: "demo.people"
          )
        end
      end
    end
  end

  def test_export_requires_capability_to_declare_export_keys
    recordable = Struct.new(:export_keys).new(["demo.people"])
    context = FakeContext.new("DemoDashboard", recordable)

    RecordingStudio.stub(:capability_options, { required_role: :view }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        assert_raises(RecordingStudioExportable::ExportNotAllowedForContext) do
          RecordingStudioExportable.export(
            context_recording: context,
            actor: Object.new,
            export_key: "demo.people"
          )
        end
      end
    end
  end

  def test_explicit_export_key_must_be_allowed_by_context_instance
    RecordingStudioExportable.configuration.context_export_keys_resolver = ->(_context) { ["demo.other"] }

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        assert_raises(RecordingStudioExportable::ExportNotAllowedForContext) do
          RecordingStudioExportable.export(
            context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
            actor: Object.new,
            export_key: "demo.people"
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

  def test_hash_style_column_definitions_are_supported
    RecordingStudioExportable.configuration.register_export(
      "demo.hash_columns",
      context_types: ["DemoDashboard"],
      columns: { payload: { label: "Payload", value: :payload } },
      replace: true
    ) { [{ payload: "safe" }] }
    RecordingStudioExportable.configuration.context_export_keys_resolver = ->(_context) { ["demo.hash_columns"] }

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.hash_columns"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        result = RecordingStudioExportable.export(
          context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
          actor: Object.new
        )

        assert_equal "Payload\nsafe\n", result.data
      end
    end
  end

  def test_export_validates_allowed_attributes_before_resolving_rows
    resolved = false
    RecordingStudioExportable.configuration.register_export(
      "demo.allowed_attributes",
      context_types: ["DemoDashboard"],
      columns: [
        { key: :name, label: "Name", value: :name }
      ],
      allowed_attributes: {
        people: [
          { key: :name, label: "Name", value: :name }
        ]
      },
      replace: true
    ) do |attributes:, **|
      resolved = true
      assert_equal({ columns: ["name"], people: ["name"] }, attributes)
      [{ name: "Ada" }]
    end
    RecordingStudioExportable.configuration.context_export_keys_resolver = ->(_context) { ["demo.allowed_attributes"] }

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.allowed_attributes"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        result = RecordingStudioExportable.export(
          context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
          actor: Object.new,
          attributes: { columns: ["name"], people: ["name"] }
        )

        assert_equal "Name\nAda\n", result.data
      end
    end
    assert resolved

    resolved = false
    RecordingStudio.stub(:capability_options, { export_keys: ["demo.allowed_attributes"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        assert_raises(RecordingStudioExportable::InvalidExportAttributes) do
          RecordingStudioExportable.export(
            context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
            actor: Object.new,
            attributes: { columns: ["name"], people: ["admin"] }
          )
        end
      end
    end
    refute resolved
  end

  def test_long_filename_preserves_csv_extension
    RecordingStudioExportable.configuration.allow_request_filename_override = true

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        result = RecordingStudioExportable.export(
          context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
          actor: Object.new,
          filename: "#{"a" * 200}.csv"
        )

        assert_equal 120, result.filename.length
        assert result.filename.end_with?(".csv")
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

  def test_definition_precedence_wins_over_capability_role_and_max_rows
    calls = []

    RecordingStudioExportable.configuration.replace_export(
      "demo.people",
      context_types: ["DemoDashboard"],
      required_role: :view,
      max_rows: 2,
      columns: [
        { key: :name, label: "Name", value: :name }
      ]
    ) { [{ name: "Ada" }, { name: "Grace" }] }

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"], required_role: :admin, max_rows: 1 }) do
      RecordingStudioAccessible.stub(:authorized?, ->(**kwargs) {
        calls << kwargs
        true
      }) do
        result = RecordingStudioExportable.export(
          context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
          actor: Object.new
        )

        assert_equal 2, result.row_count
      end
    end

    assert_equal :view, calls.first.fetch(:role)
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

  def test_export_log_and_event_include_runtime_metadata_on_success
    created_attrs = nil
    event_attrs = nil
    logged_event = nil
    fake_log = Struct.new(:updates) do
      def id
        "log-1"
      end

      def update!(**kwargs)
        updates << kwargs
      end
    end.new([])

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"] }) do
      RecordingStudioAccessible.stub(:authorized?, true) do
        RecordingStudioExportable::ExportLog.stub(:create!, ->(**kwargs) {
          created_attrs = kwargs
          fake_log
        }) do
          logger = Object.new
          logger.define_singleton_method(:log_event) do |context_recording, **kwargs|
            logged_event = kwargs.merge(context_recording: context_recording)
          end

          RecordingStudio.stub(:root_recording_or_self, logger) do
            RecordingStudio::Event.stub(:create!, ->(**kwargs) { event_attrs = kwargs }) do
              RecordingStudioExportable.export(
                context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
                actor: Struct.new(:id).new("actor-1"),
                filters: { status: "ok" },
                attributes: { columns: ["name"] }
              )
            end
          end
        end
      end
    end

    metadata = (logged_event || event_attrs).fetch(:metadata)

    assert_equal :running, created_attrs.fetch(:status)
    assert_equal :csv, created_attrs.fetch(:format)
    assert_equal ["name"], fake_log.updates.last.fetch(:attributes)
    assert_equal :completed, fake_log.updates.last.fetch(:status)
    assert_equal "demo.people", metadata.fetch(:export_key)
    assert_equal "log-1", metadata.fetch(:export_log_id)
    assert_equal [:name], metadata.fetch(:attributes).map(&:to_sym)
  end

  def test_export_log_is_marked_failed_when_validation_raises_after_log_creation
    created_attrs = nil
    fake_log = Struct.new(:updates) do
      def update!(**kwargs)
        updates << kwargs
      end
    end.new([])

    RecordingStudio.stub(:capability_options, { export_keys: ["demo.people"] }) do
      RecordingStudioAccessible.stub(:authorized?, false) do
        RecordingStudioExportable::ExportLog.stub(:create!, ->(**kwargs) {
          created_attrs = kwargs
          fake_log
        }) do
          assert_raises(RecordingStudioExportable::NotAuthorized) do
            RecordingStudioExportable.export(
              context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
              actor: Object.new
            )
          end
        end
      end
    end

    assert_equal :running, created_attrs.fetch(:status)
    assert_equal :failed, fake_log.updates.last.fetch(:status)
    assert_equal "RecordingStudioExportable::NotAuthorized", fake_log.updates.last.fetch(:error_class)
  end
end
