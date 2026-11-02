# frozen_string_literal: true

require "test_helper"

class ExportMetricsTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @admin = User.find_by!(email: "admin@admin.com")
    @document = Document.find_by!(title: "Export Governance Handbook")
    @recording = RecordingStudio.root_recording_for(@document)
  end

  test "registered exports metric counts export logs" do
    sign_in @admin

    assert_difference -> { RecordingStudioExportable::ExportLog.count }, 1 do
      post "/recording_studio_exportable/exports", params: {
        context_recording_id: @recording.id,
        export_key: "recording_studio_document_items_export",
        format: "csv"
      }
    end
    assert_response :success

    result = RecordingStudioMetrics.execute(
      "exports.total",
      context: RecordingStudioMetrics::Context.new(
        actor: @admin,
        scope: :root,
        authorized_relation: RecordingStudioExportable::ExportLog.all
      )
    )

    assert_equal RecordingStudioExportable::ExportLog.count, result.value
    assert_operator result.value, :>=, 1
  end
end