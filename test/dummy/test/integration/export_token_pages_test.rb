# frozen_string_literal: true

require "test_helper"

class ExportTokenPagesTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    workspace = Workspace.create!(name: "Token Pages Workspace #{SecureRandom.hex(4)}")
    @recording = RecordingStudio.root_recording_for(workspace)
  end

  test "token not found page renders literal English interface copy" do
    sign_in @user

    post recording_studio_exportable.exports_path, params: {
      export_token: "missing-token-for-english-assert",
      format: "csv"
    }

    assert_response :not_found
    assert_includes response.body, "Export Expired"
    assert_includes response.body, "Refresh the original page"
    assert_includes response.body, "HOST export expired nav"
  end

  test "token expired page renders literal English interface copy" do
    sign_in @user

    id = "expired-token-for-english-assert"
    token = RecordingStudioExportable::TrustedExportToken.new(
      id: id,
      context_recording: @recording,
      actor: @user,
      columns: [ { key: :title, label: "Title", value: :title } ],
      row_resolver: -> { [] },
      source: "RecordingStudioAdmin",
      screen_identifier: "English Assert",
      effective_export_key: "recordingstudioadmin.englishassert",
      expires_at: 1.minute.ago
    )
    RecordingStudioExportable::TrustedExportToken.store.write(id, token, expires_in: 5.minutes)

    post recording_studio_exportable.exports_path, params: {
      export_token: id,
      format: "csv"
    }

    assert_response :gone
    assert_includes response.body, "Export expired"
    assert_includes response.body, "Export Expired"
    assert_includes response.body, "Refresh the original page"
  end
end
