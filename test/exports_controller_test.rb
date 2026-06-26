# frozen_string_literal: true

require "test_helper"

class ExportsControllerTest < Minitest::Test
  def test_controller_maps_unauthorized_exports_to_forbidden
    handlers = RecordingStudioExportable::ExportsController.rescue_handlers

    assert(handlers.any? do |exception_name, handler|
      exception_name == "RecordingStudioExportable::NotAuthorized" && handler == :render_forbidden
    end)
    assert(handlers.any? do |exception_name, handler|
      exception_name == "ActiveRecord::RecordNotFound" && handler == :render_forbidden
    end)

    generic_index = handlers.index { |exception_name, _handler| exception_name == "RecordingStudioExportable::Error" }
    unauthorized_index = handlers.index do |exception_name, _handler|
      exception_name == "RecordingStudioExportable::NotAuthorized"
    end
    assert_operator generic_index, :<, unauthorized_index
  end

  def test_controller_maps_invalid_trusted_tokens_to_html_error_pages
    handlers = RecordingStudioExportable::ExportsController.rescue_handlers

    assert(handlers.any? do |exception_name, handler|
      exception_name == "RecordingStudioExportable::TrustedExportToken::TokenNotFound" &&
        handler == :render_token_not_found
    end)
    assert(handlers.any? do |exception_name, handler|
      exception_name == "RecordingStudioExportable::TrustedExportToken::TokenExpired" &&
        handler == :render_token_expired
    end)
  end

  def test_engine_pages_use_configurable_flatpack_layout
    source = File.read(File.expand_path("../app/controllers/recording_studio_exportable/application_controller.rb", __dir__))

    assert_includes source, "layout :recording_studio_exportable_layout"
    assert_includes source, "RecordingStudioExportable.configuration.layout"
    assert_includes source, 'lookup_context.exists?("layouts/flat_pack_sidebar") ? "flat_pack_sidebar" : "application"'
  end

  def test_token_expired_page_uses_refresh_prompt_only
    source = File.read(File.expand_path("../app/views/recording_studio_exportable/exports/token_expired.html.erb", __dir__))

    assert_includes source, "max-w-6xl"
    assert_includes source, 'title: "Export Expired"'
    assert_includes source, 'subtitle: "Refresh the original page"'
    refute_includes source, "Trusted export tokens are single-use"
    refute_includes source, "The export link you clicked is no longer valid."
  end

  def test_token_not_found_page_uses_refresh_prompt_only
    source = File.read(File.expand_path("../app/views/recording_studio_exportable/exports/token_not_found.html.erb", __dir__))

    assert_includes source, "max-w-6xl"
    assert_includes source, 'title: "Export Expired"'
    assert_includes source, 'subtitle: "Refresh the original page"'
    refute_includes source, "This export token does not exist"
    refute_includes source, "Return to the page where you generated the export"
  end

  def test_controller_does_not_render_unexpected_internal_errors
    handlers = RecordingStudioExportable::ExportsController.rescue_handlers

    refute(handlers.any? { |exception_name, _handler| exception_name == "StandardError" })
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
