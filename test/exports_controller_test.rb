# frozen_string_literal: true

require "test_helper"

class ExportsControllerTest < Minitest::Test
  def test_controller_maps_unauthorized_exports_to_forbidden
    handlers = RecordingStudioExportable::ExportsController.rescue_handlers

    assert handlers.any? { |exception_name, handler| exception_name == "RecordingStudioExportable::NotAuthorized" && handler == :render_forbidden }
  end

  def test_controller_does_not_render_unexpected_internal_errors
    handlers = RecordingStudioExportable::ExportsController.rescue_handlers

    refute handlers.any? { |exception_name, _handler| exception_name == "StandardError" }
  end

  def test_controller_permits_nested_attributes_and_filters
    source = File.read(File.expand_path("../app/controllers/recording_studio_exportable/exports_controller.rb", __dir__))

    assert_includes source, "attributes: {}"
    assert_includes source, "filters: {}"
    assert_includes source, "context_recording_id"
  end
end
