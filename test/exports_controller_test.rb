# frozen_string_literal: true

require "test_helper"

class ExportsControllerTest < Minitest::Test
  def test_controller_maps_unauthorized_exports_to_forbidden
    handlers = RecordingStudioExportable::ExportsController.rescue_handlers

    assert handlers.any? { |exception_name, handler|
      exception_name == "RecordingStudioExportable::NotAuthorized" && handler == :render_forbidden
    }
    assert handlers.any? { |exception_name, handler|
      exception_name == "ActiveRecord::RecordNotFound" && handler == :render_forbidden
    }

    generic_index = handlers.index { |exception_name, _handler| exception_name == "RecordingStudioExportable::Error" }
    unauthorized_index = handlers.index do |exception_name, _handler|
      exception_name == "RecordingStudioExportable::NotAuthorized"
    end
    assert_operator generic_index, :<, unauthorized_index
  end

  def test_controller_maps_invalid_trusted_tokens_to_bad_request
    handlers = RecordingStudioExportable::ExportsController.rescue_handlers

    assert handlers.any? { |exception_name, handler|
      exception_name == "RecordingStudioExportable::TrustedExportToken::TokenNotFound" &&
        handler == :render_bad_request
    }
    assert handlers.any? { |exception_name, handler|
      exception_name == "RecordingStudioExportable::TrustedExportToken::TokenExpired" &&
        handler == :render_bad_request
    }
  end

  def test_controller_does_not_render_unexpected_internal_errors
    handlers = RecordingStudioExportable::ExportsController.rescue_handlers

    refute handlers.any? { |exception_name, _handler| exception_name == "StandardError" }
  end

  def test_controller_permits_nested_attributes_and_filters
    source = controller_source

    assert_includes source, "attributes: [:screen_key, { columns: [] }]"
    assert_includes source, "filters: {}"
    assert_includes source, "context_recording_id"
    assert_includes source, "export_token"
  end

  def test_controller_with_token_uses_trusted_export_path
    source = controller_source

    assert_includes source, "params[:export_token].present?"
    assert_includes source, "RecordingStudioExportable.export_from_token"
    assert_includes source, "RecordingStudioExportable.export("
  end

  def test_controller_renders_generic_export_errors
    source = controller_source

    assert_includes source, '"Export is not available"'
    assert_includes source, '"Export request is invalid"'
    refute_includes source, "exception.message"
  end

  private

  def controller_source
    File.read(File.expand_path("../app/controllers/recording_studio_exportable/exports_controller.rb", __dir__))
  end
end
