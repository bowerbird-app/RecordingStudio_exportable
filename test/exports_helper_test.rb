# frozen_string_literal: true

require "test_helper"
require_relative "../app/helpers/recording_studio_exportable/exports_helper"

class ExportsHelperTest < Minitest::Test
  include RecordingStudioExportable::ExportsHelper

  def setup
    save_exportable_configuration!
  end

  def teardown
    restore_exportable_configuration!
  end

  def current_export_actor
    Object.new
  end

  def test_authorization_returns_false_for_a_gem_error
    RecordingStudioExportable.configuration.stub(:export_keys_for, ->(**_kwargs) { raise RecordingStudioExportable::NotAuthorized }) do
      refute send(:export_authorized_for_actor?, context_recording: Object.new, export_key: "demo.people")
    end
  end

  def test_authorization_raises_unexpected_errors
    RecordingStudioExportable.configuration.stub(:export_keys_for, ->(**_kwargs) { raise "boom" }) do
      assert_raises(RuntimeError) do
        send(:export_authorized_for_actor?, context_recording: Object.new, export_key: "demo.people")
      end
    end
  end

  def test_capability_export_keys_are_read_from_configuration
    context = Struct.new(:recordable_type).new("DemoDashboard")
    options = { export_keys: ["Demo.People"] }

    RecordingStudio.stub(:capability_options, options) do
      resolved = RecordingStudioExportable.configuration.capability_options_for(context)

      assert_equal ["demo.people"], RecordingStudioExportable.configuration.capability_export_keys(options)
      assert_equal ["demo.people"], RecordingStudioExportable.configuration.capability_export_keys(resolved)
    end
  end
end
