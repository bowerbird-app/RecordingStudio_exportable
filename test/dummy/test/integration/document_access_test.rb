# frozen_string_literal: true

require "test_helper"

class DocumentAccessTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @document = Document.find_by!(title: "Export Governance Handbook")
    @admin = User.find_by!(email: "admin@admin.com")
    @viewer = User.find_by!(email: "viewer@admin.com")
  end

  test "admin can view document page" do
    sign_in @admin

    get document_path(@document)

    assert_response :success
    assert_includes response.body, @document.title
    assert_includes response.body, "Export Document Items"
  end

  test "viewer cannot view document page" do
    sign_in @viewer

    get document_path(@document)

    assert_response :forbidden
  end
end
