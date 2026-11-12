# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class ExportableApiTest < Minitest::Test
  ActionContext = Struct.new(:recording, :access_grant, :params, :actor, keyword_init: true)
  ExportResult = Struct.new(:data, :filename, :content_type, :row_count, keyword_init: true)

  class AccessibleRecordings
    attr_reader :looked_up_ids

    def initialize(records)
      @records = records
      @looked_up_ids = []
    end

    def find_by(id:)
      looked_up_ids << id
      @records[id]
    end
  end

  class AccessGrant
    attr_reader :authorized_calls

    def initialize(records = {}, forbidden: false, raise_class: nil)
      @records = AccessibleRecordings.new(records)
      @authorized_calls = []
      @forbidden = forbidden
      @raise_class = raise_class
    end

    def accessible_recordings
      @records
    end

    def authorize!(recording:, role:)
      @authorized_calls << [recording, role]
      return unless @forbidden

      raise @raise_class, "API access grant is not authorized for this capability"
    end
  end

  class Recording
    attr_reader :id, :recordable_type

    def initialize(id:, recordable_type: "Document")
      @id = id
      @recordable_type = recordable_type
    end
  end

  def setup
    save_exportable_configuration!
    RecordingStudioExportable.configuration.register_export(
      "demo.people",
      required_role: :view,
      context_types: ["Document"],
      columns: [{ key: :name, label: "Name", value: :name }],
      filename: "people.csv"
    ) { |_args| [{ name: "Ada" }] }
    RecordingStudioExportable.configuration.register_export(
      "demo.admin",
      required_role: :admin,
      context_types: ["Document"],
      columns: [{ key: :name, label: "Name", value: :name }],
      filename: "admin.csv"
    ) { |_args| [{ name: "Root" }] }
  end

  def teardown
    restore_exportable_configuration!
  end

  def test_registration_is_a_noop_without_recording_studio_api
    RecordingStudioExportable::Api.stub(:recording_studio_api_available?, false) do
      assert_nil RecordingStudioExportable::Api.register_capability_action!
    end
  end

  def test_engine_registers_api_actions_before_recording_studio_api_initializes
    initializer = RecordingStudioExportable::Engine.initializers.find do |item|
      item.name == "recording_studio_exportable.register_recording_studio_api_actions"
    end

    assert initializer
    assert_equal "recording_studio_api.after_initialize", initializer.before
  end

  def test_registration_registers_export_and_export_keys_member_actions
    RecordingStudioExportable::Api.register_capability_action!

    export = RecordingStudioApi.capability_action(:export)
    keys = RecordingStudioApi.capability_action(:export_keys)

    assert_equal :exportable, export.capability
    assert_equal :post, export.http_verb
    assert_equal :member, export.scope
    assert_equal :view, export.required_role
    assert_equal RecordingStudioExportable::Api::ExportRecording, export.handler
    assert_equal "Export this recording as CSV.", export.openapi.fetch(:summary)
    assert_equal :get, keys.http_verb
    assert_equal :view, keys.required_role
    assert_equal RecordingStudioExportable::Api::ListExportKeys, keys.handler
    assert_equal "List export keys this grant may use for this recording.",
                 keys.openapi.fetch(:summary)
  end

  def test_registration_registers_public_and_named_api_surfaces_independently
    ensure_operations_api!
    RecordingStudioExportable::Api.register_capability_action!

    public_export = RecordingStudioApi.capability_action(:export, api: :public)
    operations_export = RecordingStudioApi.capability_action(:export, api: :operations)
    public_keys = RecordingStudioApi.capability_action(:export_keys, api: :public)
    operations_keys = RecordingStudioApi.capability_action(:export_keys, api: :operations)

    assert_equal RecordingStudioExportable::Api::ExportRecording, public_export.handler
    assert_equal RecordingStudioExportable::Api::ExportRecording, operations_export.handler
    assert_equal RecordingStudioExportable::Api::ListExportKeys, public_keys.handler
    assert_equal RecordingStudioExportable::Api::ListExportKeys, operations_keys.handler
  end

  def test_registration_does_not_replace_existing_actions_on_any_api_surface
    ensure_operations_api!
    RecordingStudioExportable::Api.register_capability_action!
    public_handler = RecordingStudioApi.capability_action(:export, api: :public).handler
    operations_handler = RecordingStudioApi.capability_action(:export, api: :operations).handler

    RecordingStudioExportable::Api.register_capability_action!

    assert_equal public_handler, RecordingStudioApi.capability_action(:export, api: :public).handler
    assert_equal operations_handler, RecordingStudioApi.capability_action(:export, api: :operations).handler
  end

  def test_export_handler_authorizes_then_wraps_export
    recording = Recording.new(id: "rec-1")
    access_grant = AccessGrant.new({ "rec-1" => recording })
    actor = Object.new
    captured = nil

    RecordingStudioExportable.stub(:export, lambda { |**kwargs|
      captured = kwargs
      ExportResult.new(data: "Name\nAda\n", filename: "people.csv", content_type: "text/csv", row_count: 1)
    }) do
      result = RecordingStudioExportable::Api::ExportRecording.call(
        action_context(
          recording:,
          access_grant:,
          actor:,
          params: { export_key: "demo.people", filters: { status: "ok" } }
        )
      )

      assert_equal(
        {
          export_key: "demo.people",
          filename: "people.csv",
          content_type: "text/csv",
          row_count: 1,
          data: "Name\nAda\n"
        },
        result
      )
    end

    assert_equal [[recording, :view]], access_grant.authorized_calls
    assert_equal ["rec-1"], access_grant.accessible_recordings.looked_up_ids
    assert_equal recording, captured.fetch(:context_recording)
    assert_equal actor, captured.fetch(:actor)
    assert_equal "demo.people", captured.fetch(:export_key)
    assert_equal({ status: "ok" }, captured.fetch(:filters))
  end

  def test_export_handler_uses_definition_required_role_matching_the_ui
    recording = Recording.new(id: "rec-1")
    access_grant = AccessGrant.new({ "rec-1" => recording })
    exported = false

    RecordingStudioExportable.stub(:export, lambda { |**|
      exported = true
      ExportResult.new(data: "", filename: "admin.csv", content_type: "text/csv", row_count: 0)
    }) do
      RecordingStudioExportable::Api::ExportRecording.call(
        action_context(recording:, access_grant:, params: { export_key: "demo.admin" })
      )
    end

    assert_equal [[recording, :view]], access_grant.authorized_calls
    assert exported
  end

  def test_export_handler_rejects_a_recording_outside_the_grant_root
    recording = Recording.new(id: "other-root")
    access_grant = AccessGrant.new({})
    exported = false

    RecordingStudioExportable.stub(:export, ->(**) { exported = true }) do
      error = assert_raises(RecordingStudioApi::NotFoundError) do
        RecordingStudioExportable::Api::ExportRecording.call(
          action_context(recording:, access_grant:, params: { export_key: "demo.people" })
        )
      end

      assert_equal "Recording was not found in this API scope", error.message
    end

    assert_equal ["other-root"], access_grant.accessible_recordings.looked_up_ids
    assert_empty access_grant.authorized_calls
    refute exported
  end

  def test_export_handler_does_not_export_when_authorize_forbids_the_role
    recording = Recording.new(id: "rec-1")
    exported = false
    access_grant = AccessGrant.new(
      { "rec-1" => recording },
      forbidden: true,
      raise_class: RecordingStudioApi::AuthorizationError
    )

    RecordingStudioExportable.stub(:export, ->(**) { exported = true }) do
      error = assert_raises(RecordingStudioApi::AuthorizationError) do
        RecordingStudioExportable::Api::ExportRecording.call(
          action_context(recording:, access_grant:, params: { export_key: "demo.people" })
        )
      end

      assert_equal "API access grant is not authorized for this capability", error.message
    end

    assert_equal [[recording, :view]], access_grant.authorized_calls
    refute exported
  end

  def test_list_export_keys_returns_keys_from_configuration
    recording = Recording.new(id: "rec-1")
    access_grant = AccessGrant.new({ "rec-1" => recording })
    actor = Object.new
    listed = nil

    RecordingStudioExportable.configuration.stub(:export_keys_for, lambda { |**kwargs|
      listed = kwargs
      %w[demo.people]
    }) do
      result = RecordingStudioExportable::Api::ListExportKeys.call(
        action_context(recording:, access_grant:, actor:, params: { screen_key: "home" })
      )

      assert_equal({ export_keys: %w[demo.people] }, result)
    end

    assert_equal [[recording, :view]], access_grant.authorized_calls
    assert_equal recording, listed.fetch(:recording)
    assert_equal actor, listed.fetch(:actor)
    assert_equal "home", listed.fetch(:context)
  end

  def test_list_export_keys_rejects_a_recording_outside_the_grant_root
    recording = Recording.new(id: "other-root")
    access_grant = AccessGrant.new({})
    listed = false

    RecordingStudioExportable.configuration.stub(:export_keys_for, ->(**) { listed = true }) do
      error = assert_raises(RecordingStudioApi::NotFoundError) do
        RecordingStudioExportable::Api::ListExportKeys.call(
          action_context(recording:, access_grant:, params: {})
        )
      end

      assert_equal "Recording was not found in this API scope", error.message
    end

    assert_empty access_grant.authorized_calls
    refute listed
  end

  def test_list_export_keys_does_not_list_when_authorize_forbids_view
    recording = Recording.new(id: "rec-1")
    listed = false
    access_grant = AccessGrant.new(
      { "rec-1" => recording },
      forbidden: true,
      raise_class: RecordingStudioApi::AuthorizationError
    )

    RecordingStudioExportable.configuration.stub(:export_keys_for, ->(**) { listed = true }) do
      assert_raises(RecordingStudioApi::AuthorizationError) do
        RecordingStudioExportable::Api::ListExportKeys.call(
          action_context(recording:, access_grant:, params: {})
        )
      end
    end

    refute listed
  end

  private

  def action_context(recording:, access_grant:, params:, actor: Object.new)
    ActionContext.new(recording:, access_grant:, params:, actor:)
  end

  def ensure_operations_api!
    RecordingStudioApi.configure do |config|
      config.api :operations do |api|
        api.openapi_title = "Operations API"
        api.api_versions = %w[v1]
      end
    end
  end
end
