# frozen_string_literal: true

require "test_helper"

class ExportRateLimitTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @admin = User.find_by!(email: "admin@admin.com")
    @document = Document.find_by!(title: "Export Governance Handbook")
    @recording = RecordingStudio.root_recording_for(@document)
    @previous_store = RecordingStudioCache.configuration.cache_store
    @previous_limit = RecordingStudioExportable.configuration.export_rate_limit
    RecordingStudioCache.configuration.cache_store = ActiveSupport::Cache::MemoryStore.new
    RecordingStudioExportable.configuration.export_rate_limit = 1
  end

  teardown do
    RecordingStudioCache.configuration.cache_store = @previous_store
    RecordingStudioExportable.configuration.export_rate_limit = @previous_limit
  end

  test "a second export in the window is rejected" do
    sign_in @admin
    params = {
      context_recording_id: @recording.id,
      export_key: "recording_studio_document_items_export",
      format: "csv"
    }

    post "/recording_studio_exportable/exports", params: params
    assert_response :success

    post "/recording_studio_exportable/exports", params: params
    assert_response :too_many_requests
    assert_equal "Too many exports. Try again soon.", response.body
    assert response.headers["Retry-After"].present?
  end

  test "a different export key still shares the actor bucket" do
    sign_in @admin

    post "/recording_studio_exportable/exports", params: {
      context_recording_id: @recording.id,
      export_key: "recording_studio_document_items_export",
      format: "csv"
    }
    assert_response :success

    post "/recording_studio_exportable/exports", params: {
      context_recording_id: @recording.id,
      export_key: "some.other.export",
      format: "csv"
    }
    assert_response :too_many_requests
  end

  test "another actor is not limited by the first actor" do
    viewer = User.find_by!(email: "viewer@admin.com")
    dashboard = DemoDashboard.find_by!(name: "Export Demo Dashboard")
    recording = RecordingStudio.root_recording_for(dashboard)
    params = {
      context_recording_id: recording.id,
      export_key: "recording_studio_demo_dashboard_requests_export",
      format: "csv"
    }

    sign_in @admin
    post "/recording_studio_exportable/exports", params: params
    assert_response :success
    post "/recording_studio_exportable/exports", params: params
    assert_response :too_many_requests

    sign_in viewer
    post "/recording_studio_exportable/exports", params: params
    assert_response :success
  end
end
