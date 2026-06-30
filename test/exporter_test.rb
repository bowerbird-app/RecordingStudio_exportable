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
      @resolved_filters = filters
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
          attributes: { columns: %w[name enabled formula] },
          filters: { "nested" => { "status" => "ok" } }
        )

        assert_equal "'=Name,Enabled,Formula\nAda,false,'=1+1\n'+Grace,true,safe\n", result.data
        assert_equal "People-Export.csv", result.filename
        assert_equal 2, result.row_count
        assert_equal({ "nested" => { "status" => "ok" } }, @resolved_filters)
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
          filename: "#{'a' * 200}.csv"
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
    ) { raise "internal secret token" }
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
    full_body = source[/def call_full_export.*?^    end/m]

    assert_operator full_body.index("create_export_log(definition"), :<,
                    full_body.index("validate_authorization!(definition)")
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
      RecordingStudioAccessible.stub(:authorized?, lambda { |**kwargs|
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
    RecordingStudioExportable.configuration.context_export_keys_resolver = lambda { |_context|
      ["demo.people", "demo.other"]
    }

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
        RecordingStudioExportable::ExportLog.stub(:create!, lambda { |**kwargs|
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
        RecordingStudioExportable::ExportLog.stub(:create!, lambda { |**kwargs|
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

  def test_trusted_export_produces_csv_from_supplied_rows_and_columns
    result = trusted_export(rows: [{ name: "Ada" }])

    assert_equal "Name\nAda\n", result.data
    assert_equal 1, result.row_count
  end

  def test_trusted_export_applies_csv_formula_sanitization
    result = trusted_export(rows: [{ name: "=1+1" }])

    assert_equal "Name\n'=1+1\n", result.data
  end

  def test_trusted_export_sanitizes_formula_like_non_string_values
    result = trusted_export(rows: [{ name: :"=1+1" }])

    assert_equal "Name\n'=1+1\n", result.data
  end

  def test_trusted_export_enforces_max_rows
    RecordingStudioExportable.configuration.max_rows = 1

    assert_raises(RecordingStudioExportable::ExportTooLarge) do
      trusted_export(rows: [{ name: "Ada" }, { name: "Grace" }])
    end
  end

  def test_trusted_export_rejects_non_csv_format
    assert_raises(RecordingStudioExportable::InvalidExportFormat) do
      trusted_export(format: :json)
    end
  end

  def test_trusted_export_creates_completed_export_log
    fake_log = Struct.new(:updates) do
      def id = "log-1"
      def update!(**kwargs) = updates << kwargs
    end.new([])
    created_attrs = nil

    RecordingStudioExportable::ExportLog.stub(:create!, lambda { |**kwargs|
      created_attrs = kwargs
      fake_log
    }) do
      trusted_export(rows: [{ name: "Ada" }])
    end

    assert_equal :running, created_attrs.fetch(:status)
    assert_equal "admin.users", created_attrs.fetch(:export_key)
    assert_equal :completed, fake_log.updates.last.fetch(:status)
    assert_equal "RecordingStudioAdmin", fake_log.updates.last.fetch(:metadata).fetch(:trusted_source)
    assert_equal "users", fake_log.updates.last.fetch(:metadata).fetch(:screen_identifier)
  end

  def test_trusted_export_marks_log_failed_on_domain_error
    fake_log = Struct.new(:updates) do
      def update!(**kwargs) = updates << kwargs
    end.new([])

    RecordingStudioExportable::ExportLog.stub(:create!, ->(**_kwargs) { fake_log }) do
      assert_raises(RecordingStudioExportable::InvalidExportFormat) do
        trusted_export(format: :json)
      end
    end

    assert_equal :failed, fake_log.updates.last.fetch(:status)
    assert_equal "RecordingStudioExportable::InvalidExportFormat", fake_log.updates.last.fetch(:error_class)
  end

  def test_trusted_export_marks_log_failed_when_row_resolver_raises
    fake_log = Struct.new(:updates) do
      def update!(**kwargs) = updates << kwargs
    end.new([])

    RecordingStudioExportable::ExportLog.stub(:create!, ->(**_kwargs) { fake_log }) do
      assert_raises(RuntimeError) do
        trusted_export(rows: -> { raise "resolver failed" })
      end
    end

    assert_equal :failed, fake_log.updates.last.fetch(:status)
    assert_equal "RuntimeError", fake_log.updates.last.fetch(:error_class)
  end

  def test_trusted_export_requires_rows
    assert_raises(ArgumentError) do
      trusted_export(rows: nil)
    end
  end

  def test_trusted_export_requires_columns
    assert_raises(ArgumentError) do
      trusted_export(columns: nil)
    end
  end

  def test_trusted_export_requires_actor
    assert_raises(ArgumentError) do
      trusted_export(actor: nil)
    end
  end

  def test_trusted_export_includes_bom_when_configured
    RecordingStudioExportable.configuration.include_bom = true

    assert trusted_export.data.start_with?("\uFEFF")
  end

  def test_trusted_export_event_includes_trusted_metadata
    logged_event = nil
    logger = Object.new
    logger.define_singleton_method(:log_event) do |context_recording, **kwargs|
      logged_event = kwargs.merge(context_recording: context_recording)
    end

    RecordingStudio.stub(:root_recording_or_self, logger) do
      trusted_export
    end

    metadata = logged_event.fetch(:metadata)
    assert_equal "RecordingStudioAdmin", metadata.fetch(:trusted_source)
    assert_equal "users", metadata.fetch(:screen_identifier)
    assert_equal "admin.users", metadata.fetch(:export_key)
  end

  def test_trusted_export_uses_fallback_export_key
    created_attrs = nil

    RecordingStudioExportable::ExportLog.stub(:create!, lambda { |**kwargs|
      created_attrs = kwargs
      nil
    }) do
      trusted_export(export_key: nil)
    end

    assert_match(/\Atrusted\.[0-9a-f]{8}\z/, created_attrs.fetch(:export_key))
  end

  def test_trusted_export_materializes_relation_like_rows_with_take
    relation = Class.new do
      attr_reader :requested

      def initialize(rows)
        @rows = rows
      end

      def take(limit)
        @requested = limit
        @rows.take(limit)
      end
    end.new([{ name: "Ada" }, { name: "Grace" }])

    RecordingStudioExportable.configuration.max_rows = 1

    assert_raises(RecordingStudioExportable::ExportTooLarge) do
      trusted_export(rows: relation)
    end
    assert_equal 2, relation.requested
  end

  def test_trusted_export_materializes_enumerator_rows
    rows = Enumerator.new do |yielder|
      yielder << { name: "Ada" }
    end

    assert_equal "Name\nAda\n", trusted_export(rows: rows).data
  end

  def test_trusted_export_rejects_nil_rows_before_materialization
    assert_raises(ArgumentError) do
      trusted_export(rows: nil)
    end
  end

  def test_trusted_export_filename_uses_export_key
    assert_equal "admin-users.csv", trusted_export.filename
  end

  private

  def trusted_export(rows: [{ name: "Ada" }], columns: [trusted_column(:name)], actor: Object.new,
                     export_key: "admin.users", format: :csv)
    RecordingStudioExportable::Exporter.call(
      context_recording: FakeContext.new("DemoDashboard", FakeRecordable.new("Dash")),
      actor: actor,
      export_key: export_key,
      trusted_export: true,
      rows: rows,
      columns: columns,
      trusted_source: "RecordingStudioAdmin",
      screen_identifier: "users",
      format: format
    )
  end

  def trusted_column(key)
    RecordingStudioExportable::ExportDefinition::Column.new(key: key, label: key.to_s.titleize, value: key)
  end
end
