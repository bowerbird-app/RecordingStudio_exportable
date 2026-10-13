# frozen_string_literal: true

require "test_helper"

class ExportPlainErrorsI18nTest < ActionDispatch::IntegrationTest
  HOST_NOT_AVAILABLE = "HOST export is not available"
  BOOT_OVERRIDE_KEY = "recording_studio.exportable.errors.not_available"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_exportable_host.en.yml")

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    workspace = Workspace.create!(name: "Plain Errors Workspace #{SecureRandom.hex(4)}")
    @recording = RecordingStudio.root_recording_for(workspace)
    @load_path_before = I18n.load_path.dup
  end

  teardown do
    assert_equal @load_path_before, I18n.load_path,
                 "test must not leave I18n.load_path modified"
  end

  test "host locale override for errors.not_available wins on boot order" do
    assert_path_exists BOOT_HOST_LOCALE
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_NOT_AVAILABLE
    assert_equal HOST_NOT_AVAILABLE, I18n.t(BOOT_OVERRIDE_KEY)
    assert_equal @load_path_before, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    sign_in @user
    post recording_studio_exportable.exports_path, params: {
      context_recording_id: SecureRandom.uuid,
      export_key: "recording_studio_article_export",
      format: "csv"
    }

    assert_response :forbidden
    assert_equal HOST_NOT_AVAILABLE, response.body
  end

  test "invalid export request renders gem English plain text" do
    sign_in @user

    post recording_studio_exportable.exports_path, params: {
      context_recording_id: @recording.id,
      export_key: "missing.export.key.#{SecureRandom.hex(4)}",
      format: "csv"
    }

    assert_response :bad_request
    assert_equal "Export request is invalid", response.body
    refute_includes response.body, HOST_NOT_AVAILABLE
  end
end
