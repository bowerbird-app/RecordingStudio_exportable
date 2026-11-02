# frozen_string_literal: true

require "test_helper"

class AdminExportTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @admin = User.find_by!(email: "admin@admin.com")
    @document = Document.find_by!(title: "Export Governance Handbook")
    @recording = RecordingStudio.root_recording_for(@document)
  end

  test "signed-in admin export writes one completed log and returns csv" do
    sign_in @admin

    assert_difference -> { RecordingStudioExportable::ExportLog.completed.count }, 1 do
      post "/recording_studio_exportable/exports", params: {
        context_recording_id: @recording.id,
        export_key: "recording_studio_document_items_export",
        format: "csv"
      }
    end

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "Item,Description"

    log = RecordingStudioExportable::ExportLog.order(:created_at).last
    assert_equal "completed", log.status
    assert_equal "recording_studio_document_items_export", log.export_key
    assert_equal @recording.id, log.context_recording_id
    assert log.selected_columns.present?
    assert_operator log.row_count, :>, 0

    events = RecordingStudio::Event.where(recording_id: @recording.id, action: "exported")
    assert_equal 1, events.count
    assert_equal "export:#{log.id}", events.pick(:idempotency_key)

    @recording.log_event!(
      action: "exported",
      actor: @admin,
      idempotency_key: "export:#{log.id}",
      metadata: { replayed: true }
    )

    assert_equal 1, RecordingStudio::Event.where(recording_id: @recording.id, action: "exported").count
  end
end
