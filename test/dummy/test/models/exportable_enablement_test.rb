# frozen_string_literal: true

require "test_helper"

class ExportableEnablementTest < ActiveSupport::TestCase
  test "dummy recordables opt in with Exportable.to and workspace stays without it" do
    assert_respond_to RecordingStudio::Capabilities::Exportable, :to
    assert RecordingStudio.capability_enabled?(:exportable, for: "DemoDashboard")
    assert RecordingStudio.capability_enabled?(:exportable, for: "Article")
    assert RecordingStudio.capability_enabled?(:exportable, for: "Document")
    refute RecordingStudio.capability_enabled?(:exportable, for: "Workspace")
    refute RecordingStudio.capability_enabled?(:exportable, for: "Folder")
    refute RecordingStudio.capability_enabled?(:exportable, for: "Page")
  end

  test "installing the gem registers exportable without enabling it on every type" do
    assert RecordingStudio.registered_capabilities.key?(:exportable)
    refute_includes RecordingStudio.capabilities_for("Workspace"), :exportable
    assert_includes RecordingStudio.capabilities_for("DemoDashboard"), :exportable
  end

  test "dummy dashboard export options come from the include factory" do
    options = RecordingStudio.capability_options(:exportable, for: "DemoDashboard")

    assert_includes options.fetch(:export_keys), "recording_studio_demo_dashboard_requests_export"
    assert_includes options.fetch(:export_keys), "recording_studio_article_export"
  end
end
