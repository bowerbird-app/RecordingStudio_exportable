# frozen_string_literal: true

require "test_helper"

class ExportableApiTest < ActionDispatch::IntegrationTest
  BASE = "/recording_studio_api/api/v1"

  setup do
    skip "recording_studio_api is not available" unless defined?(RecordingStudioApi)

    @previous_actor = Current.actor
    @owner = user("owner")
    @viewer = user("viewer")
    @stranger = user("stranger")
    Current.actor = @owner
    @document = owned_root(Document.create!(title: "API Export Handbook #{SecureRandom.hex(4)}"))
    @other = owned_root(Document.create!(title: "Other handbook #{SecureRandom.hex(4)}"), actor: @stranger)
    Item.create!(document: @document.recordable, name: "Owner", description: "Escalation contact")
    @viewer_access = grant!(@document, @viewer, :view)
    @view_token, = token_for(@viewer_access)
  end

  teardown { Current.actor = @previous_actor }

  test "a view grant exports" do
    body = call(:post, "/documents/#{@document.id}/actions/export", @view_token,
                export_key: "recording_studio_document_items_export")

    assert_response :success, response.body
    assert_equal "recording_studio_document_items_export", body.fetch("export_key")
    assert_equal "text/csv; charset=utf-8", body.fetch("content_type")
    assert_equal 1, body.fetch("row_count")
    assert_includes body.fetch("data"), "Owner"
  end

  test "an export definition that requires admin returns 403 for a view grant" do
    call(:post, "/documents/#{@document.id}/actions/export", @view_token,
         export_key: "recording_studio_document_admin_export")

    assert_response :forbidden, response.body
  end

  test "a recording in a foreign workspace returns 404" do
    call(:post, "/documents/#{@other.id}/actions/export", @view_token,
         export_key: "recording_studio_document_items_export")

    assert_response :not_found, response.body
  end

  test "export_keys lists keys" do
    body = call(:get, "/documents/#{@document.id}/actions/export_keys", @view_token)

    assert_response :success, response.body
    keys = body.fetch("export_keys")
    assert_includes keys, "recording_studio_document_items_export"
    refute_includes keys, "recording_studio_document_admin_export"
  end

  private

  def user(name)
    User.create!(
      email: "#{name}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
  end

  def owned_root(recordable, actor: @owner)
    root = RecordingStudio.root_recording_for(recordable)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor:)
    raise result.error if result.failure?

    root
  end

  def grant!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(recording:, actor:, role:, manager_actor: @owner)
    raise result.error if result.failure?

    result.value
  end

  def token_for(access_recording)
    RecordingStudioAccessible::AccessCreationContext.allow do
      provision = RecordingStudioApi::Services::ProvisionApiClient.call(
        access_point_recording: access_recording.parent_recording || access_recording.root_recording,
        manager_actor: @owner,
        role: access_recording.recordable.role,
        name: "Client #{SecureRandom.hex(3)}"
      )
      raise provision.error unless provision.success?

      issued = RecordingStudioApi::Services::IssueOauthAccessToken.call(
        grant_type: "client_credentials",
        client_id: provision.value.fetch(:credential).oauth_client_id,
        client_secret: provision.value.fetch(:token)
      )
      raise issued.error unless issued.success?

      [issued.value.fetch(:access_token), provision.value.fetch(:api_client)]
    end
  end

  def call(method, path, token, params = {})
    send(method, "#{BASE}#{path}", params:, headers: {
      "Authorization" => "Bearer #{token}",
      "Accept" => "application/json"
    }, as: :json)
    response.media_type.to_s.include?("json") ? JSON.parse(response.body) : {}
  rescue JSON::ParserError
    {}
  end
end
