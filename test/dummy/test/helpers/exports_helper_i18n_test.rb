# frozen_string_literal: true

require "test_helper"

class ExportsHelperI18nTest < ActionView::TestCase
  include RecordingStudioExportable::ExportsHelper
  include Rails.application.routes.url_helpers if defined?(Rails)

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    workspace = Workspace.create!(name: "Helper I18n Workspace #{SecureRandom.hex(4)}")
    @recording = RecordingStudio.root_recording_for(workspace)
    @routes = RecordingStudioExportable::Engine.routes
  end

  test "default Export CSV label renders when text is omitted" do
    html = recording_studio_export_button(
      context_recording: @recording,
      export_key: "recording_studio_article_export"
    )

    assert_includes html, "Export CSV"
  end

  test "default Export CSV label renders when text is explicitly nil" do
    html = recording_studio_export_button(
      context_recording: @recording,
      export_key: "recording_studio_article_export",
      text: nil
    )

    assert_includes html, "Export CSV"
  end

  test "empty string text is rendered as-is without default label" do
    html = recording_studio_export_button(
      context_recording: @recording,
      export_key: "recording_studio_article_export",
      text: ""
    )

    refute_includes html, "Export CSV"
  end

  test "custom text replaces the default Export CSV label" do
    html = recording_studio_export_button(
      context_recording: @recording,
      export_key: "recording_studio_article_export",
      text: "Custom export label"
    )

    assert_includes html, "Custom export label"
    refute_includes html, "Export CSV"
  end

  test "unauthorized_text replaces the default label on a disabled access button" do
    html = recording_studio_export_access_button(
      context_recording: @recording,
      export_key: "recording_studio_article_export",
      unauthorized_behavior: :disable,
      unauthorized_text: "Export restricted"
    )

    assert_includes html, "Export restricted"
    refute_includes html, "Export CSV"
  end

  test "access button without unauthorized_text uses the default Export CSV label when unauthorized" do
    html = recording_studio_export_access_button(
      context_recording: @recording,
      export_key: "recording_studio_article_export",
      unauthorized_behavior: :disable
    )

    assert_includes html, "Export CSV"
  end

  private

  def recording_studio_exportable
    RecordingStudioExportable::Engine.routes.url_helpers
  end

  def form_authenticity_token
    "test-token"
  end

  def protect_against_forgery?
    false
  end

  def controller
    @controller ||= ApplicationController.new
  end
end
