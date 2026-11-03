# frozen_string_literal: true

require "test_helper"

class TrustedTokenAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @admin = User.find_by!(email: "admin@admin.com")
    @viewer = User.find_by!(email: "viewer@admin.com")
    @dashboard = DemoDashboard.find_by!(name: "Export Demo Dashboard")
    @recording = RecordingStudio.root_recording_for(@dashboard)
  end

  test "a signed-in user without access does not receive a trusted token" do
    outsider = User.create!(
      email: "outsider-#{SecureRandom.hex(4)}@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    sign_in outsider

    get root_path

    assert_response :success
    refute_includes response.body, "Export Articles (token-based)"
  end

  test "another user cannot redeem a trusted export token" do
    token = RecordingStudioExportable.issue_trusted_token(
      context_recording: @recording,
      actor: @admin,
      source: "RecordingStudioExportable",
      screen_identifier: "Homepage Demo Export",
      columns: [ { key: :title, label: "Title", value: :title } ],
      row_resolver: -> { [] }
    )
    sign_in @viewer

    post recording_studio_exportable.exports_path, params: {
      export_token: token.id,
      format: "csv"
    }

    assert_response :forbidden
  end
end
