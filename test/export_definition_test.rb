# frozen_string_literal: true

require "test_helper"

class ExportDefinitionTest < Minitest::Test
  def test_render_generates_csv_with_sanitized_filename
    definition = RecordingStudioExportable::ExportDefinition.new(
      key: "demo.people",
      headers: ["Name"],
      filename: "Unsafe / People"
    ) { [{ "Name" => "Ada" }] }

    RecordingStudioAccessible.stub(:authorized?, true) do
      result = definition.render(recording: Object.new, actor: Object.new)

      assert_equal "Name\nAda\n", result.fetch(:data)
      assert_equal "Unsafe-People.csv", result.fetch(:filename)
      assert_equal "text/csv; charset=utf-8", result.fetch(:content_type)
      assert_equal 1, result.fetch(:row_count)
    end
  end

  def test_render_fails_closed_when_row_limit_is_exceeded
    definition = RecordingStudioExportable::ExportDefinition.new(
      key: "demo.people",
      headers: ["Name"],
      row_limit: 1
    ) { [{ "Name" => "Ada" }, { "Name" => "Grace" }] }

    RecordingStudioAccessible.stub(:authorized?, true) do
      assert_raises(RecordingStudioExportable::RowLimitExceeded) do
        definition.render(recording: Object.new, actor: Object.new)
      end
    end
  end

  def test_render_requires_authorization
    definition = RecordingStudioExportable::ExportDefinition.new(key: "demo.people", headers: ["Name"]) { [] }

    RecordingStudioAccessible.stub(:authorized?, false) do
      assert_raises(RecordingStudioExportable::AuthorizationError) do
        definition.render(recording: Object.new, actor: Object.new)
      end
    end
  end

  def test_requires_callable_exporter_and_headers
    assert_raises(RecordingStudioExportable::InvalidExportDefinition) do
      RecordingStudioExportable::ExportDefinition.new(key: "demo.people", headers: ["Name"])
    end

    assert_raises(RecordingStudioExportable::InvalidExportDefinition) do
      RecordingStudioExportable::ExportDefinition.new(key: "demo.people") { [] }
    end
  end
end
