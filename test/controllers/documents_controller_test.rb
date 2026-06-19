# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "devise/test/integration_helpers"
require "rails/test_help"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s

    @user = User.find_by!(email: "admin@admin.com")
    @document = Document.find_by!(title: "Export Governance Handbook")
    @recording = RecordingStudio::Recording.find_by!(recordable: @document)

    sign_in @user
  end

  test "show uses existing recording when root lookup is unavailable" do
    RecordingStudio.stub(:root_recording_for, lambda { |_recordable|
      raise RecordingStudio::RootNotAllowed, "parent_recording_id is required for Document"
    }) do
      get document_path(@document)
    end

    assert_response :success
    assert_includes response.body, @document.title
    assert_includes response.body, "Owner"
  end
end
