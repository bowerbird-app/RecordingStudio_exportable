# frozen_string_literal: true

require "test_helper"

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
    refute Object.const_defined?(:RecordingStudioApi, false)

    assert_nil RecordingStudioExportable::Api.register_capability_action!
  end

  def test_engine_registers_api_actions_before_recording_studio_api_initializes
    initializer = RecordingStudioExportable::Engine.initializers.find do |item|
      item.name == "recording_studio_exportable.register_recording_studio_api_actions"
    end

    assert initializer
    assert_equal "recording_studio_api.after_initialize", initializer.before
  end

  def test_registration_registers_export_and_export_keys_member_actions
    with_fake_recording_studio_api do |api|
      RecordingStudioExportable::Api.register_capability_action!

      names = api.registrations.map { |registration| registration.fetch(:name) }
      export = api.registrations.find { |registration| registration.fetch(:name) == :export }
      keys = api.registrations.find { |registration| registration.fetch(:name) == :export_keys }

      assert_equal %i[export export_keys], names
      assert_equal :exportable, export.fetch(:capability)
      assert_equal :post, export.fetch(:http_verb)
      assert_equal :member, export.fetch(:scope)
      assert_equal :view, export.fetch(:required_role)
      assert_equal RecordingStudioExportable::Api::ExportRecording, export.fetch(:handler)
      assert_equal "Export this recording as CSV.", export.fetch(:openapi).fetch(:summary)
      assert_equal :get, keys.fetch(:http_verb)
      assert_equal :view, keys.fetch(:required_role)
      assert_equal RecordingStudioExportable::Api::ListExportKeys, keys.fetch(:handler)
      assert_equal "List export keys this grant may use for this recording.",
                   keys.fetch(:openapi).fetch(:summary)
    end
  end

  def test_registration_registers_public_and_named_api_surfaces_independently
    with_fake_recording_studio_api(api_names: %w[public operations]) do |api|
      RecordingStudioExportable::Api.register_capability_action!
      registered = api.registrations.map { |registration| [registration.fetch(:api), registration.fetch(:name)] }

      assert_equal(
        [["public", :export], ["public", :export_keys], ["operations", :export], ["operations", :export_keys]],
        registered
      )
    end
  end

  def test_registration_does_not_replace_existing_actions_on_any_api_surface
    existing_actions = { "public" => { export: Object.new, export_keys: Object.new } }

    with_fake_recording_studio_api(api_names: %w[public operations], existing_actions:) do |api|
      RecordingStudioExportable::Api.register_capability_action!
      registered_apis = api.registrations.map { |registration| registration.fetch(:api) }.uniq

      assert_equal ["operations"], registered_apis
    end
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
      with_fake_recording_studio_api do
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

    RecordingStudioExportable.stub(:export, ExportResult.new(data: "", filename: "admin.csv",
                                                             content_type: "text/csv", row_count: 0)) do
      with_fake_recording_studio_api do
        RecordingStudioExportable::Api::ExportRecording.call(
          action_context(recording:, access_grant:, params: { export_key: "demo.admin" })
        )
      end
    end

    assert_equal [[recording, :admin]], access_grant.authorized_calls
  end

  def test_export_handler_rejects_a_recording_outside_the_grant_root
    recording = Recording.new(id: "other-root")
    access_grant = AccessGrant.new({})
    exported = false

    RecordingStudioExportable.stub(:export, ->(**) { exported = true }) do
      with_fake_recording_studio_api do |api|
        error = assert_raises(api.not_found_error) do
          RecordingStudioExportable::Api::ExportRecording.call(
            action_context(recording:, access_grant:, params: { export_key: "demo.people" })
          )
        end

        assert_equal "Recording was not found in this API scope", error.message
      end
    end

    assert_equal ["other-root"], access_grant.accessible_recordings.looked_up_ids
    assert_empty access_grant.authorized_calls
    refute exported
  end

  def test_export_handler_does_not_export_when_authorize_forbids_the_role
    recording = Recording.new(id: "rec-1")
    exported = false

    with_fake_recording_studio_api do |api|
      access_grant = AccessGrant.new(
        { "rec-1" => recording },
        forbidden: true,
        raise_class: api.authorization_error
      )

      RecordingStudioExportable.stub(:export, ->(**) { exported = true }) do
        error = assert_raises(api.authorization_error) do
          RecordingStudioExportable::Api::ExportRecording.call(
            action_context(recording:, access_grant:, params: { export_key: "demo.people" })
          )
        end

        assert_equal "API access grant is not authorized for this capability", error.message
      end

      assert_equal [[recording, :view]], access_grant.authorized_calls
    end

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
      with_fake_recording_studio_api do
        result = RecordingStudioExportable::Api::ListExportKeys.call(
          action_context(recording:, access_grant:, actor:, params: { screen_key: "home" })
        )

        assert_equal({ export_keys: %w[demo.people] }, result)
      end
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
      with_fake_recording_studio_api do |api|
        error = assert_raises(api.not_found_error) do
          RecordingStudioExportable::Api::ListExportKeys.call(
            action_context(recording:, access_grant:, params: {})
          )
        end

        assert_equal "Recording was not found in this API scope", error.message
      end
    end

    assert_empty access_grant.authorized_calls
    refute listed
  end

  def test_list_export_keys_does_not_list_when_authorize_forbids_view
    recording = Recording.new(id: "rec-1")
    listed = false

    with_fake_recording_studio_api do |api|
      access_grant = AccessGrant.new(
        { "rec-1" => recording },
        forbidden: true,
        raise_class: api.authorization_error
      )

      RecordingStudioExportable.configuration.stub(:export_keys_for, ->(**) { listed = true }) do
        assert_raises(api.authorization_error) do
          RecordingStudioExportable::Api::ListExportKeys.call(
            action_context(recording:, access_grant:, params: {})
          )
        end
      end
    end

    refute listed
  end

  private

  def action_context(recording:, access_grant:, params:, actor: Object.new)
    ActionContext.new(recording:, access_grant:, params:, actor:)
  end

  def with_fake_recording_studio_api(existing_actions: {}, api_names: nil)
    api = Module.new
    invalid_action_input_error = Class.new(StandardError) do
      attr_reader :details

      def initialize(message, details: [])
        super(message)
        @details = details
      end
    end

    api.const_set(:UnsupportedActionError, Class.new(StandardError))
    api.const_set(:InvalidActionInputError, invalid_action_input_error)
    api.const_set(:AuthorizationError, Class.new(StandardError))
    api.const_set(:NotFoundError, Class.new(StandardError))
    api.instance_variable_set(:@existing_actions, existing_actions.transform_keys(&:to_s))
    api.instance_variable_set(:@registrations, [])

    if api_names
      define_api_0_2_behavior(api, api_names)
    else
      api.define_singleton_method(:capability_action) { |_name| nil }
      api.define_singleton_method(:register_capability_action) do |name, **options|
        @registrations << options.merge(name:)
      end
    end

    api.define_singleton_method(:registrations) { @registrations }
    api.define_singleton_method(:not_found_error) { const_get(:NotFoundError) }
    api.define_singleton_method(:authorization_error) { const_get(:AuthorizationError) }
    api.define_singleton_method(:invalid_action_input_error) { const_get(:InvalidActionInputError) }

    Object.const_set(:RecordingStudioApi, api)
    yield api
  ensure
    Object.send(:remove_const, :RecordingStudioApi) if Object.const_defined?(:RecordingStudioApi, false)
  end

  def define_api_0_2_behavior(api, api_names)
    configuration = fake_api_configuration(api_names)

    api.define_singleton_method(:configuration) { configuration }
    api.define_singleton_method(:capability_action) do |name, api: :public|
      actions = @existing_actions[api.to_s] || {}
      actions[name] || actions[name.to_sym]
    end
    api.define_singleton_method(:register_capability_action) do |name, api: :public, **options|
      @registrations << options.merge(name:, api: api.to_s)
    end
  end

  def fake_api_configuration(api_names)
    definitions = api_names.map { |name| Struct.new(:name).new(name.to_s) }
    Struct.new(:definitions) do
      def each_api(&)
        definitions.each(&)
      end
    end.new(definitions)
  end
end
