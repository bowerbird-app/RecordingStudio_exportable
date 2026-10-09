# frozen_string_literal: true

require "test_helper"

class HostLocaleOverrideTest < ActionDispatch::IntegrationTest
  HOST_NOT_FOUND_NAV = "HOST export expired nav"

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    workspace = Workspace.create!(name: "Host Locale Override Workspace #{SecureRandom.hex(4)}")
    @recording = RecordingStudio.root_recording_for(workspace)
  end

  test "host config/locales English override wins on the token not found page" do
    override_path = Rails.root.join("config/locales/exportable_host_override.en.yml")

    assert_path_exists override_path, "expected host override file in test/dummy/config/locales/"
    refute_includes File.read(override_path), "I18n.load_path"
    assert_equal HOST_NOT_FOUND_NAV, I18n.t("recording_studio.exportable.tokens.not_found.nav_title")

    sign_in @user
    post recording_studio_exportable.exports_path, params: {
      export_token: "missing-token-for-host-override",
      format: "csv"
    }

    assert_response :not_found
    assert_includes response.body, HOST_NOT_FOUND_NAV
    assert_includes response.body, "Export Expired"
    assert_includes response.body, "Refresh the original page"
    refute_includes response.body, "<title>Export expired</title>"
  end

  test "token expired page keeps gem English nav title outside the host override" do
    sign_in @user

    id = "expired-token-for-host-override"
    token = RecordingStudioExportable::TrustedExportToken.new(
      id: id,
      context_recording: @recording,
      actor: @user,
      columns: [ { key: :title, label: "Title", value: :title } ],
      row_resolver: -> { [] },
      source: "RecordingStudioAdmin",
      screen_identifier: "Host Override",
      effective_export_key: "recordingstudioadmin.hostoverride",
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
    refute_includes response.body, HOST_NOT_FOUND_NAV
  end
end
