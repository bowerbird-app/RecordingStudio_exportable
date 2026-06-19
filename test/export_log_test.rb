# frozen_string_literal: true

require "test_helper"

class ExportLogTest < Minitest::Test
  def test_export_log_exposes_expected_scopes
    source = File.read(File.expand_path("../app/models/recording_studio_exportable/export_log.rb", __dir__))

    assert_includes source, "scope :for_context_recording"
    assert_includes source, "scope :for_actor"
    assert_includes source, "scope :completed"
    assert_includes source, "scope :failed"
  end

  def test_format_validation_avoids_kernel_format_method_conflict
    source = File.read(File.expand_path("../app/models/recording_studio_exportable/export_log.rb", __dir__))

    refute_includes source, "validates :export_key, :content_type, :format, :status, presence: true"
    assert_includes source, "validate :format_value_must_be_present"
    assert_includes source, "self[:format].blank?"
  end
end
